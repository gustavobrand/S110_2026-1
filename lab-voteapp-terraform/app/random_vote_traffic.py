#!/usr/bin/env python3
"""Generate random vote traffic (a/b) to the voting app endpoint."""

import argparse
import random
import time
import urllib.error
import urllib.parse
import urllib.request


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate random vote POST requests against the vote endpoint "
            "with configurable request rate."
        )
    )
    parser.add_argument(
        "--url",
        default="http://vote.local/",
        help="Vote endpoint URL (default: http://vote.local/)",
    )
    parser.add_argument(
        "--rate",
        type=float,
        default=2.0,
        help="Target rate in requests/second (default: 2.0)",
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=60.0,
        help="How long to run in seconds (default: 60)",
    )
    parser.add_argument(
        "--p-a",
        type=float,
        default=0.5,
        help="Probability of vote 'a' (0.0 to 1.0, default: 0.5)",
    )
    parser.add_argument(
        "--timeout",
        type=float,
        default=3.0,
        help="HTTP timeout in seconds for each request (default: 3)",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=None,
        help="Optional RNG seed for reproducible runs",
    )
    return parser.parse_args()


def send_vote(url: str, vote: str, timeout: float) -> int:
    payload = urllib.parse.urlencode({"vote": vote}).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=payload,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )

    with urllib.request.urlopen(req, timeout=timeout) as response:
        return response.getcode()


def main() -> int:
    args = parse_args()

    if args.rate <= 0:
        raise SystemExit("--rate must be > 0")
    if args.duration <= 0:
        raise SystemExit("--duration must be > 0")
    if not (0.0 <= args.p_a <= 1.0):
        raise SystemExit("--p-a must be between 0 and 1")

    if args.seed is not None:
        random.seed(args.seed)

    interval = 1.0 / args.rate
    total = 0
    vote_a = 0
    vote_b = 0
    ok = 0
    fail = 0

    print(
        f"Starting traffic: url={args.url} rate={args.rate:.3f} req/s "
        f"duration={args.duration:.1f}s p_a={args.p_a:.2f}"
    )

    start = time.monotonic()
    end_time = start + args.duration
    next_at = start

    while True:
        now = time.monotonic()
        if now >= end_time:
            break

        if now < next_at:
            time.sleep(next_at - now)

        vote = "a" if random.random() < args.p_a else "b"
        total += 1
        if vote == "a":
            vote_a += 1
        else:
            vote_b += 1

        try:
            status = send_vote(args.url, vote, args.timeout)
            if 200 <= status < 400:
                ok += 1
            else:
                fail += 1
        except (urllib.error.URLError, TimeoutError):
            fail += 1

        next_at += interval

    elapsed = max(time.monotonic() - start, 1e-9)
    effective_rate = total / elapsed

    print("Done")
    print(f"  requests_total: {total}")
    print(f"  requests_ok:    {ok}")
    print(f"  requests_fail:  {fail}")
    print(f"  votes_a:        {vote_a}")
    print(f"  votes_b:        {vote_b}")
    print(f"  elapsed_sec:    {elapsed:.3f}")
    print(f"  effective_rate: {effective_rate:.3f} req/s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
