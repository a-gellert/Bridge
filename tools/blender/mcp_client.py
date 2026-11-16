"""Minimal client for the BlenderMCP addon socket (the same bridge the MCP server uses).

Used when the MCP-for-Unity bridge is unavailable, so the studio/asset scripts can still
be driven through a live Blender instead of a headless process.

    python tools/blender/mcp_client.py --code "print('hi')"
    python tools/blender/mcp_client.py --file some_script.py

The addon listens on 127.0.0.1:9876 (Blender > MCP for Unity > Blender Bridge).
"""

import argparse
import json
import socket
import sys
import time

HOST = "127.0.0.1"
PORT = 9876


def send(command, params, host=HOST, port=PORT, timeout=1800.0):
    payload = json.dumps({"type": command, "params": params}).encode("utf-8") + b"\n"
    with socket.create_connection((host, port), timeout=10.0) as sock:
        sock.settimeout(timeout)
        sock.sendall(payload)

        chunks = []
        raw = ""
        while True:
            chunk = sock.recv(65536)
            if not chunk:
                break
            chunks.append(chunk)
            raw = b"".join(chunks).decode("utf-8", "replace")
            # the addon does not terminate replies with a newline: stop at the first
            # complete JSON document instead.
            try:
                json.loads(raw)
                break
            except json.JSONDecodeError:
                continue
        raw = raw.strip()
    if not raw:
        return {"status": "error", "message": "empty response"}
    return json.loads(raw)


def execute_code(code, **kwargs):
    return send("execute_code", {"code": code}, **kwargs)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Run Python inside a live Blender via BlenderMCP.")
    parser.add_argument("--code", help="inline Python to execute")
    parser.add_argument("--file", help="Python file to execute")
    parser.add_argument("--host", default=HOST)
    parser.add_argument("--port", type=int, default=PORT)
    parser.add_argument("--timeout", type=float, default=1800.0)
    parser.add_argument("--out", help="write the raw JSON response here")
    args = parser.parse_args(argv)

    if args.file:
        with open(args.file, encoding="utf-8-sig") as fh:
            code = fh.read()
    elif args.code:
        code = args.code
    else:
        code = sys.stdin.read()

    started = time.time()
    response = execute_code(code, host=args.host, port=args.port, timeout=args.timeout)
    elapsed = time.time() - started

    if args.out:
        with open(args.out, "w", encoding="utf-8") as fh:
            json.dump(response, fh, indent=2)

    status = response.get("status")
    result = response.get("result", {})
    if isinstance(result, dict) and "result" in result:
        result = result["result"]
    if isinstance(result, dict) and "stdout" in result:
        sys.stdout.write(result["stdout"])
    elif isinstance(result, str):
        sys.stdout.write(result)
    else:
        sys.stdout.write(json.dumps(response, indent=2))
    sys.stdout.write(f"\n[mcp] {status} in {elapsed:.1f}s\n")
    return 0 if status == "success" else 1


if __name__ == "__main__":
    raise SystemExit(main())
