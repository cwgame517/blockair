"""수치표/CSV → Config 모듈 생성기.

사용법:  python tools/export_config.py
data/blocks_v2.csv 를 읽어 src/shared/Config/Blocks.luau 를 다시 만든다.
블록 id는 CSV 행 순서(1부터)이며, 섬 청크에서 0은 빈 칸(공기)이다.
CSV에 행을 추가할 때는 맨 아래에만 추가해야 기존 id가 바뀌지 않는다.
"""
import csv
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "blocks_v2.csv"
OUT = ROOT / "src" / "shared" / "Config" / "Blocks.luau"


def lua_str(s: str) -> str:
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def main() -> None:
    rows = list(csv.DictReader(SRC.open(encoding="utf-8-sig")))
    lines = [
        "--!strict",
        "-- 자동 생성 파일: tools/export_config.py 로 다시 만든다. 직접 고치지 말 것.",
        "-- 원본: data/blocks_v2.csv",
        "",
        "export type Block = {",
        "\tid: number, key: string, name: string, grade: string, tier: number,",
        "\tfamily: string, layer: string, hardness: number, weight: number,",
        "\tminePower: number, unlockLevel: number, price: number, flavor: string,",
        "}",
        "",
        "local list: { Block } = {",
    ]
    for i, r in enumerate(rows, start=1):
        mine = float(r["채굴력기여"].lstrip("x"))
        lines.append(
            "\t{ id = %d, key = %s, name = %s, grade = %s, tier = %s, family = %s, layer = %s, "
            "hardness = %s, weight = %s, minePower = %s, unlockLevel = %s, price = %s, flavor = %s },"
            % (
                i,
                lua_str(r["원작name"]),
                lua_str(r["새이름"]),
                lua_str(r["원작등급"]),
                r["티어(원작그룹)"],
                lua_str(r["계열"]),
                lua_str(r["출현층"]),
                r["블록HP"],
                r["무게"],
                f"{mine:g}",
                r["해금레벨"],
                r["판매가"],
                lua_str(r.get("설명", "") or ""),
            )
        )
    lines += [
        "}",
        "",
        "local byId: { [number]: Block } = {}",
        "local byKey: { [string]: Block } = {}",
        "for _, b in list do",
        "\tbyId[b.id] = b",
        "\tbyKey[b.key] = b",
        "end",
        "",
        "return { list = list, byId = byId, byKey = byKey }",
        "",
    ]
    OUT.write_text("\n".join(lines), encoding="utf-8")
    print(f"{len(rows)} blocks -> {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
