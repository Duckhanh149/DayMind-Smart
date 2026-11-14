"""Prevent dependency-download credentials from following CDN redirects."""
import io
import os
import unittest
from urllib.error import HTTPError
from urllib.request import HTTPRedirectHandler
from unittest.mock import patch

from upstream_github import download


class UpstreamDownload(unittest.TestCase):
    def test_actions_token_is_not_forwarded_to_an_asset_redirect(self):
        with patch.dict(os.environ, {'GITHUB_TOKEN': 'synthetic-ci-marker'}), \
                patch('upstream_github.urlopen', return_value=io.BytesIO(b'asset')) as opened:
            self.assertEqual(download('https://api.github.com/repos/example/project/releases/assets/1', 'application/octet-stream'), b'asset')
        request = opened.call_args.args[0]
        self.assertTrue(request.has_header('Authorization'))
        redirected = HTTPRedirectHandler().redirect_request(request, None, 302, '', {},
            'https://release-assets.githubusercontent.com/example')
        self.assertFalse(redirected.has_header('Authorization'))

    def test_anonymous_local_download_is_still_supported(self):
        with patch.dict(os.environ, {'GITHUB_TOKEN': ''}), \
                patch('upstream_github.urlopen', return_value=io.BytesIO(b'asset')) as opened:
            download('https://api.github.com/repos/example/project/releases/tags/pinned', 'application/json')
        self.assertFalse(opened.call_args.args[0].has_header('Authorization'))

    def test_authentication_is_never_sent_to_an_arbitrary_origin(self):
        with patch('upstream_github.urlopen') as opened:
            for url in ['http://api.github.com/path', 'https://api.github.com.attacker.invalid/path',
                        'https://user@api.github.com/path']:
                with self.assertRaises(ValueError):
                    download(url, 'application/json')
        opened.assert_not_called()

    def test_rate_limit_is_not_blindly_retried(self):
        error = HTTPError('https://api.github.com/path', 403, 'rate limit', {}, None)
        with patch('upstream_github.urlopen', side_effect=error) as opened:
            with self.assertRaises(HTTPError):
                download('https://api.github.com/path', 'application/json')
        self.assertEqual(opened.call_count, 1)

    def test_known_transient_gateway_errors_have_a_bounded_retry(self):
        error = HTTPError('https://api.github.com/path', 503, 'gateway', {}, None)
        with patch('upstream_github.urlopen', side_effect=[error, io.BytesIO(b'asset')]) as opened:
            self.assertEqual(download('https://api.github.com/path', 'application/json'), b'asset')
        self.assertEqual(opened.call_count, 2)


if __name__ == '__main__':
    unittest.main()
