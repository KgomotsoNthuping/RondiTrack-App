import difflib
import json
import sys
from pathlib import Path

if len(sys.argv) != 2:
    raise SystemExit("Usage: python tool/check_api_contract.py <api-checkout>")

source = json.loads(Path("contract/source.json").read_text(encoding="utf-8-sig"))
api_root = Path(sys.argv[1]).resolve()
api_contract = (api_root / source["path"]).resolve()
api_contract.relative_to(api_root)


def canonical(path):
    document = json.loads(path.read_text(encoding="utf-8-sig"))
    return json.dumps(document, sort_keys=True, indent=2, ensure_ascii=False) + "\n"


local = canonical(Path("contract/openapi/v1.json"))
remote = canonical(api_contract)

if local != remote:
    sys.stdout.writelines(difflib.unified_diff(
        local.splitlines(keepends=True),
        remote.splitlines(keepends=True),
        fromfile="contract/openapi/v1.json",
        tofile=source["path"],
    ))
    raise SystemExit(1)

print("Contract matches the API checkout.")