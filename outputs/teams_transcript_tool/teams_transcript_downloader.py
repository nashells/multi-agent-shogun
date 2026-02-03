#!/usr/bin/env python3
"""
Microsoft Teams Transcript Downloader

This script downloads meeting transcripts from Microsoft Teams using the Microsoft Graph API.
It supports OAuth2.0 authentication and provides transcript listing and download capabilities.

Requirements:
- Python 3.7+
- Valid Azure AD app registration with appropriate permissions
- Required permissions: OnlineMeetings.Read, OnlineMeetingTranscript.Read.All
"""

import os
import sys
import logging
import argparse
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional

import re
import yaml
import msal
import requests


def sanitize_sensitive_data(text: str) -> str:
    """
    Sanitize sensitive information from log messages.

    Args:
        text: Text that may contain sensitive information

    Returns:
        Sanitized text with sensitive data masked
    """
    if not text:
        return text

    # Patterns to sanitize
    patterns = [
        (r'(access[_-]?token[":\s]+)([^\s",}]+)', r'\1***REDACTED***'),
        (r'(bearer\s+)([^\s",}]+)', r'\1***REDACTED***', re.IGNORECASE),
        (r'(client[_-]?secret[":\s]+)([^\s",}]+)', r'\1***REDACTED***'),
        (r'(password[":\s]+)([^\s",}]+)', r'\1***REDACTED***'),
        (r'(secret[":\s]+)([^\s",}]+)', r'\1***REDACTED***'),
        (r'(authorization[":\s]+)([^\s",}]+)', r'\1***REDACTED***', re.IGNORECASE),
    ]

    sanitized = text
    for pattern, replacement, *flags in patterns:
        flag = flags[0] if flags else 0
        sanitized = re.sub(pattern, replacement, sanitized, flags=flag)

    return sanitized


class ConfigLoader:
    """Handles loading and validation of configuration files."""

    def __init__(self, config_path: str = "config.yaml"):
        """
        Initialize the configuration loader.

        Args:
            config_path: Path to the YAML configuration file
        """
        self.config_path = config_path
        self.config = None

    def load(self) -> Dict:
        """
        Load configuration from YAML file.

        Returns:
            Configuration dictionary

        Raises:
            FileNotFoundError: If config file doesn't exist
            yaml.YAMLError: If config file is invalid
        """
        if not os.path.exists(self.config_path):
            raise FileNotFoundError(
                f"Configuration file not found: {self.config_path}\n"
                f"Please copy config.yaml.example to config.yaml and fill in your credentials."
            )

        try:
            with open(self.config_path, 'r', encoding='utf-8') as f:
                self.config = yaml.safe_load(f)

            self._validate_config()
            return self.config

        except yaml.YAMLError as e:
            raise yaml.YAMLError(f"Invalid YAML in configuration file: {e}")

    def _validate_config(self) -> None:
        """Validate required configuration fields."""
        required_fields = {
            'azure': ['tenant_id', 'client_id', 'client_secret', 'scopes'],
            'graph_api': ['base_url'],
            'output': ['directory'],
        }

        for section, fields in required_fields.items():
            if section not in self.config:
                raise ValueError(f"Missing required configuration section: {section}")

            for field in fields:
                if field not in self.config[section]:
                    raise ValueError(f"Missing required field: {section}.{field}")

        # Validate HTTPS for Graph API URLs
        base_url = self.config['graph_api'].get('base_url', '')
        beta_url = self.config['graph_api'].get('beta_url', '')

        if base_url and not base_url.startswith('https://'):
            raise ValueError(f"graph_api.base_url must use HTTPS: {base_url}")

        if beta_url and not beta_url.startswith('https://'):
            raise ValueError(f"graph_api.beta_url must use HTTPS: {beta_url}")


class AuthManager:
    """Manages OAuth2.0 authentication with Microsoft Graph API."""

    def __init__(self, config: Dict):
        """
        Initialize the authentication manager.

        Args:
            config: Configuration dictionary containing Azure AD credentials
        """
        self.config = config
        self.authority = f"https://login.microsoftonline.com/{config['azure']['tenant_id']}"
        self.client_id = config['azure']['client_id']
        self.client_secret = config['azure']['client_secret']
        self.scopes = config['azure']['scopes']
        self.access_token = None

        # Initialize MSAL confidential client
        self.app = msal.ConfidentialClientApplication(
            self.client_id,
            authority=self.authority,
            client_credential=self.client_secret,
        )

    def get_access_token(self) -> str:
        """
        Acquire an access token for Microsoft Graph API.

        Returns:
            Access token string

        Raises:
            RuntimeError: If authentication fails
        """
        logging.info("Acquiring access token...")

        # Try to get token from cache first
        result = self.app.acquire_token_silent(self.scopes, account=None)

        if not result:
            logging.info("No cached token found. Acquiring new token...")
            result = self.app.acquire_token_for_client(scopes=self.scopes)

        if "access_token" in result:
            self.access_token = result["access_token"]
            logging.info("Access token acquired successfully")
            return self.access_token
        else:
            error_msg = result.get("error_description", result.get("error", "Unknown error"))
            sanitized_error = sanitize_sensitive_data(str(error_msg))
            logging.error(f"Authentication failed: {sanitized_error}")
            raise RuntimeError(f"Failed to acquire access token: {sanitized_error}")


class TeamsTranscriptDownloader:
    """Main class for downloading Microsoft Teams transcripts."""

    def __init__(self, config: Dict, auth_manager: AuthManager):
        """
        Initialize the transcript downloader.

        Args:
            config: Configuration dictionary
            auth_manager: AuthManager instance for handling authentication
        """
        self.config = config
        self.auth_manager = auth_manager
        self.base_url = config['graph_api']['base_url']
        self.beta_url = config['graph_api'].get('beta_url', 'https://graph.microsoft.com/beta')
        self.output_dir = Path(config['output']['directory'])

        # Create output directory if it doesn't exist
        self.output_dir.mkdir(parents=True, exist_ok=True)

    def _get_headers(self) -> Dict[str, str]:
        """
        Get HTTP headers with authentication token.

        Returns:
            Dictionary of HTTP headers
        """
        token = self.auth_manager.get_access_token()
        return {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json',
        }

    def _make_request(self, url: str, method: str = 'GET') -> requests.Response:
        """
        Make an HTTP request to Microsoft Graph API with error handling.

        Args:
            url: Full URL to request
            method: HTTP method (GET, POST, etc.)

        Returns:
            Response object

        Raises:
            requests.RequestException: If request fails
        """
        try:
            headers = self._get_headers()
            response = requests.request(method, url, headers=headers, timeout=30)
            response.raise_for_status()
            return response

        except requests.exceptions.HTTPError as e:
            logging.error(f"HTTP error occurred: {e}")
            response_text = e.response.text if e.response else 'No response'
            sanitized_response = sanitize_sensitive_data(response_text)
            logging.error(f"Response: {sanitized_response}")
            raise
        except requests.exceptions.RequestException as e:
            logging.error(f"Request failed: {e}")
            raise

    def list_online_meetings(self, user_id: str = 'me', max_results: int = 50) -> List[Dict]:
        """
        List online meetings for a user.

        Args:
            user_id: User ID or 'me' for current user
            max_results: Maximum number of meetings to retrieve

        Returns:
            List of meeting dictionaries
        """
        logging.info(f"Fetching online meetings for user: {user_id}")

        # Note: This endpoint requires delegated permissions (user context)
        # For application permissions, you may need to use /users/{userId}/onlineMeetings
        url = f"{self.base_url}/users/{user_id}/onlineMeetings?$top={max_results}"

        try:
            response = self._make_request(url)
            meetings = response.json().get('value', [])
            logging.info(f"Found {len(meetings)} online meetings")
            return meetings

        except requests.RequestException as e:
            logging.warning(f"Could not retrieve meetings: {e}")
            return []

    def list_transcripts(self, meeting_id: str, user_id: str = 'me') -> List[Dict]:
        """
        List transcripts for a specific meeting.

        Args:
            meeting_id: Microsoft Teams meeting ID
            user_id: User ID or 'me' for current user

        Returns:
            List of transcript dictionaries
        """
        logging.info(f"Fetching transcripts for meeting: {meeting_id}")

        # Using beta endpoint as transcripts API may not be fully available in v1.0
        url = f"{self.beta_url}/users/{user_id}/onlineMeetings/{meeting_id}/transcripts"

        try:
            response = self._make_request(url)
            transcripts = response.json().get('value', [])
            logging.info(f"Found {len(transcripts)} transcripts")
            return transcripts

        except requests.RequestException as e:
            logging.warning(f"Could not retrieve transcripts for meeting {meeting_id}: {e}")
            return []

    def download_transcript(self, meeting_id: str, transcript_id: str, output_filename: Optional[str] = None, user_id: str = 'me') -> Optional[str]:
        """
        Download transcript content and save to file.

        Args:
            meeting_id: Microsoft Teams meeting ID
            transcript_id: Transcript ID
            output_filename: Optional custom output filename
            user_id: User ID or 'me' for current user

        Returns:
            Path to saved transcript file, or None if download fails
        """
        logging.info(f"Downloading transcript: {transcript_id}")

        # Get transcript content
        url = f"{self.beta_url}/users/{user_id}/onlineMeetings/{meeting_id}/transcripts/{transcript_id}/content"

        try:
            response = self._make_request(url)
            content = response.text

            # Generate filename if not provided
            if not output_filename:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                output_filename = f"transcript_{transcript_id}_{timestamp}.vtt"

            # Save to file
            output_path = self.output_dir / output_filename
            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(content)

            logging.info(f"Transcript saved to: {output_path}")
            return str(output_path)

        except requests.RequestException as e:
            logging.error(f"Failed to download transcript {transcript_id}: {e}")
            return None

    def download_latest_transcript(self, user_id: str = 'me') -> Optional[str]:
        """
        Download the most recent transcript available.

        Args:
            user_id: User ID or 'me' for current user

        Returns:
            Path to saved transcript file, or None if no transcripts found
        """
        logging.info("Searching for latest transcript...")

        # Get online meetings
        meetings = self.list_online_meetings(user_id)

        if not meetings:
            logging.warning("No online meetings found")
            return None

        # Search through meetings for transcripts
        for meeting in meetings:
            meeting_id = meeting.get('id')
            if not meeting_id:
                continue

            transcripts = self.list_transcripts(meeting_id, user_id)

            if transcripts:
                # Get the first (most recent) transcript
                latest_transcript = transcripts[0]
                transcript_id = latest_transcript.get('id')

                if transcript_id:
                    return self.download_transcript(meeting_id, transcript_id, user_id=user_id)

        logging.warning("No transcripts found in any meeting")
        return None


def setup_logging(config: Dict) -> None:
    """
    Configure logging based on configuration settings.

    Args:
        config: Configuration dictionary
    """
    log_level = config.get('logging', {}).get('level', 'INFO')
    log_file = config.get('logging', {}).get('file')

    logging_config = {
        'level': getattr(logging, log_level.upper()),
        'format': '%(asctime)s - %(name)s - %(levelname)s - %(message)s',
        'datefmt': '%Y-%m-%d %H:%M:%S',
    }

    if log_file:
        logging_config['filename'] = log_file
        logging_config['filemode'] = 'a'

    logging.basicConfig(**logging_config)


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description='Download Microsoft Teams meeting transcripts using Graph API'
    )
    parser.add_argument(
        '--config',
        default='config.yaml',
        help='Path to configuration file (default: config.yaml)'
    )
    parser.add_argument(
        '--list-meetings',
        action='store_true',
        help='List all online meetings'
    )
    parser.add_argument(
        '--meeting-id',
        help='Meeting ID to download transcripts from'
    )
    parser.add_argument(
        '--download-latest',
        action='store_true',
        help='Download the latest available transcript'
    )
    parser.add_argument(
        '--user-id',
        default='me',
        help='User ID (default: me - current user)'
    )

    args = parser.parse_args()

    try:
        # Load configuration
        config_loader = ConfigLoader(args.config)
        config = config_loader.load()

        # Setup logging
        setup_logging(config)
        logging.info("=== Microsoft Teams Transcript Downloader Started ===")

        # Initialize authentication
        auth_manager = AuthManager(config)

        # Initialize downloader
        downloader = TeamsTranscriptDownloader(config, auth_manager)

        # Execute requested action
        if args.list_meetings:
            meetings = downloader.list_online_meetings(args.user_id)
            print(f"\nFound {len(meetings)} online meetings:")
            for i, meeting in enumerate(meetings, 1):
                print(f"{i}. {meeting.get('subject', 'No subject')} (ID: {meeting.get('id')})")

        elif args.meeting_id:
            transcripts = downloader.list_transcripts(args.meeting_id)
            if transcripts:
                print(f"\nFound {len(transcripts)} transcripts:")
                for i, transcript in enumerate(transcripts, 1):
                    print(f"{i}. Transcript ID: {transcript.get('id')}")

                # Download first transcript
                if transcripts:
                    transcript_id = transcripts[0].get('id')
                    output_path = downloader.download_transcript(args.meeting_id, transcript_id)
                    if output_path:
                        print(f"\nTranscript downloaded to: {output_path}")

        elif args.download_latest or config.get('download', {}).get('auto_download_latest', False):
            output_path = downloader.download_latest_transcript(args.user_id)
            if output_path:
                print(f"\nLatest transcript downloaded to: {output_path}")
            else:
                print("\nNo transcripts available to download")

        else:
            parser.print_help()

        logging.info("=== Microsoft Teams Transcript Downloader Finished ===")
        return 0

    except FileNotFoundError as e:
        logging.error(f"Configuration error: {e}")
        print(f"\nError: {e}", file=sys.stderr)
        return 1

    except ValueError as e:
        logging.error(f"Configuration validation error: {e}")
        print(f"\nError: {e}", file=sys.stderr)
        return 1

    except RuntimeError as e:
        logging.error(f"Authentication error: {e}")
        print(f"\nError: {e}", file=sys.stderr)
        return 1

    except Exception as e:
        logging.exception(f"Unexpected error occurred: {e}")
        print(f"\nUnexpected error: {e}", file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
