"""
Save storage.

The v0.1 game kept everything in `PlayerPrefs` as a single blob, which cannot
express what Silver Mountain needs: a save *point* the player is returned to
when they fail the summit, per-realm progress, and a knowledge trace that must
survive a 24-hour cooldown.

So saves are versioned JSON files, one per player, written atomically (temp file
then replace) so a crash mid-write cannot corrupt an existing save. This is also
the "save point throughout the world" architecture: `last_save` is a real
position in the world, not a bookmark in a menu.
"""

from __future__ import annotations

import json
import logging
import os
import re
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Dict, List, Optional

logger = logging.getLogger("kaiserquest.saves")

SAVE_VERSION = 2
DEFAULT_DIR = Path(__file__).resolve().parent.parent / "data" / "saves"

_SAFE_ID = re.compile(r"[^A-Za-z0-9_.-]")


def safe_player_id(player_id: str) -> str:
    """Player ids become filenames, so they are sanitised, not trusted."""
    cleaned = _SAFE_ID.sub("_", str(player_id or ""))[:120].strip("._")
    return cleaned or "unknown"


@dataclass
class SaveSummary:
    player_id: str
    name: str = ""
    realm: str = ""
    level_label: str = ""
    updated_at: float = 0.0
    milestone_index: int = 1
    place: str = ""
    cleared_realms: List[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "player_id": self.player_id,
            "name": self.name,
            "realm": self.realm,
            "level_label": self.level_label,
            "updated_at": self.updated_at,
            "milestone_index": self.milestone_index,
            "place": self.place,
            "cleared_realms": list(self.cleared_realms),
        }


class SaveStore:
    def __init__(self, directory: Optional[Path] = None):
        self.directory = directory or DEFAULT_DIR
        self.directory.mkdir(parents=True, exist_ok=True)

    def path_for(self, player_id: str) -> Path:
        return self.directory / f"{safe_player_id(player_id)}.json"

    def load(self, player_id: str) -> Optional[dict]:
        path = self.path_for(player_id)
        if not path.exists():
            return None
        try:
            with open(path, "r", encoding="utf-8") as handle:
                payload = json.load(handle)
        except (json.JSONDecodeError, OSError) as exc:
            logger.error("Corrupt save for %s (%s); starting fresh", player_id, exc)
            return None
        version = int(payload.get("version", 1))
        if version > SAVE_VERSION:
            logger.warning(
                "Save for %s is version %d but this build understands %d; loading anyway",
                player_id, version, SAVE_VERSION,
            )
        return payload

    def save(self, player_id: str, payload: dict) -> Path:
        path = self.path_for(player_id)
        payload = dict(payload)
        payload["version"] = SAVE_VERSION
        payload["updated_at"] = time.time()

        handle = tempfile.NamedTemporaryFile(
            "w",
            encoding="utf-8",
            dir=str(self.directory),
            prefix=".tmp-",
            delete=False,
            suffix=".json",
        )
        temp_path = Path(handle.name)
        try:
            with handle:
                json.dump(payload, handle, indent=2, ensure_ascii=False)
                handle.flush()
                os.fsync(handle.fileno())
            os.replace(temp_path, path)
        except BaseException:
            temp_path.unlink(missing_ok=True)
            raise
        logger.debug("Saved %s", path.name)
        return path

    def delete(self, player_id: str) -> bool:
        path = self.path_for(player_id)
        if path.exists():
            path.unlink()
            return True
        return False

    def list_saves(self) -> List[SaveSummary]:
        summaries: List[SaveSummary] = []
        for path in sorted(self.directory.glob("*.json")):
            try:
                with open(path, "r", encoding="utf-8") as handle:
                    payload = json.load(handle)
            except (json.JSONDecodeError, OSError):
                continue
            last_save = payload.get("last_save") or {}
            realms = payload.get("realms") or {}
            cleared = [r for r, data in realms.items() if (data.get("silver_mountain") or {}).get("cleared")]
            summaries.append(
                SaveSummary(
                    player_id=payload.get("player_id", path.stem),
                    name=payload.get("name", ""),
                    realm=payload.get("realm", ""),
                    level_label=payload.get("level_label", ""),
                    updated_at=float(payload.get("updated_at", 0.0)),
                    milestone_index=int(last_save.get("milestone_index", 1)),
                    place=last_save.get("place", ""),
                    cleared_realms=cleared,
                )
            )
        summaries.sort(key=lambda s: -s.updated_at)
        return summaries


_STORE: Optional[SaveStore] = None


def get_save_store() -> SaveStore:
    global _STORE
    if _STORE is None:
        _STORE = SaveStore()
    return _STORE
