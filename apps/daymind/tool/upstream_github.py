"""Read public upstream release assets within the Actions API quota.

Credentials only accompany the exact HTTPS API host and never redirects to the
asset CDN. Callers still verify the pinned package's own SHA256 before use.
"""
import os
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import Request, urlopen


def download(url, accept):
    parsed = urlparse(url)
    if parsed.scheme != 'https' or parsed.netloc != 'api.github.com':
        raise ValueError('Only the upstream HTTPS GitHub API is supported.')
    for attempt in range(3):
        request = Request(url, headers={
            'Accept': accept,
            'User-Agent': 'DayMind pinned dependency precache',
        })
        token = os.environ.get('GITHUB_TOKEN', '')
        if token:
            # urllib deliberately omits these headers from redirected requests.
            request.add_unredirected_header('Authorization', 'Bearer ' + token)
        try:
            with urlopen(request, timeout=45) as response:
                return response.read()
        except HTTPError as error:
            if error.code not in (502, 503, 504) or attempt == 2:
                raise
        except (URLError, TimeoutError):
            if attempt == 2:
                raise
