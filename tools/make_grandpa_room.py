"""One-time converter: scenes/world/shop_room.tscn (Mr. Hemming's v7 shop, in the town)
-> scenes/world/grandpa/grandpa_shop_room.tscn (same town and plot, greybox grandpa shell,
day-1 stations only). Re-run only while grandpa's room is still machine-made; once it is
edited by hand in Godot, this script must not be run again (it overwrites the file).

    python tools/make_grandpa_room.py
"""
import io, re, sys, os

SRC = "scenes/world/shop_room.tscn"
OUT = "scenes/world/grandpa/grandpa_shop_room.tscn"
SHELL = "res://scenes/world/grandpa/grandpa_shell_greybox.tscn"

DROP = {"Walls", "TailorShop", "NewHouseBase2", "MaterialRoll", "FabricPiece",
        "GarmentPiece", "Suit"}
DROP_PARENTS = ("Walls", "TailorShop", "NewHouseBase2")

I = "1, 0, 0, 0, 1, 0, 0, 0, 1"                      # faces +Z (the street / camera)
FACE_PX = "-4.371139e-08, 0, 1, 0, 1, 0, -1, 0, -4.371139e-08"   # faces +X (on a west wall)
FACE_NX = "-4.371139e-08, 0, -1, 0, 1, 0, 1, 0, -4.371139e-08"  # faces -X (on an east wall)
ROT_M45 = "0.70710677, 0, -0.70710677, 0, 1, 0, 0.70710677, 0, 0.70710677"
MOVE = {  # docs/STORY_AND_RENOVATION.md 6.5: everything the loop needs, in the front room
    "Shelf": (I, (-3.55, 0, 1.95)),
    "Worktable": (I, (-1.6, 0, 2.5)),
    "SewingMachine": (I, (1.6, 0, 2.4)),
    "ClothingRack": (FACE_PX, (-3.6, 0, 4.4)),
    # the desk runs x -0.35..1.65 from the Phone's origin: this centres it on x = -1.1
    "Phone": (I, (-1.75, 0, 4.6)),
    # The tri-fold is 2.46 m wide: flat on the east wall it costs 0.6 m of depth, set
    # diagonally it walled off a third of the room (tools/test_shop_clearance.gd map).
    "Mirror": (FACE_NX, (1.9, 0, 5.6)),
    "TrashCan": (I, (-3.85, 0, 6.45)),
    # Not there on day 1: RenovationDirector / UpgradeStation keep these hidden and
    # switched off until their room is done. They sit in the scene all along so that
    # their save paths never change.
    "Bookshelf": (I, (1.75, 0, 1.95)),
    "Shelf2": (I, (4.15, 0, -3.1)),
    "CoffeeMachine": (I, (4.2, 0, 1.95)),
    "IroningBoard": (I, (4.4, 0, 5.6)),
    "ApprenticeBench": (I, (8.1, 0, -2.7)),
    "Mannequin": (I, (8.2, 0, 5.4)),  # a step back from the glass: room to walk round it
    "Waypoints/GreetSpot": (I, (-1.55, 0, 5.9)),
    "Waypoints/CollectSpot": (I, (-0.65, 0, 5.9)),
    "Waypoints/DoorInside": (I, (-0.85, 0, 6.4)),
    "Waypoints/DoorOutside": (I, (-0.85, 0, 8.3)),
    "Waypoints/MirrorSpot": (FACE_NX, (1.0, 0, 5.6)),
}

# UpgradeStations that also wait for a room (stations/upgrade_station.gd `room`).
UPGRADE_ROOMS = {"CoffeeMachine": "nook", "IroningBoard": "nook",
                 "ApprenticeBench": "nextdoor"}
# More of a station the source scene already has: (name, ext_resource id, basis, origin).
EXTRA = [
    ("ClothingRack2", "11_26bn3", FACE_PX, (-3.6, 0, -0.6)),
    ("ClothingRack3", "11_26bn3", FACE_NX, (10.0, 0, 1.0)),
    ("Shelf3", "1_2a88l", FACE_NX, (5.25, 0, -0.9)),
    ("Shelf4", "1_2a88l", FACE_NX, (5.25, 0, 0.55)),
]
DIRECTOR = "res://scenes/world/grandpa/renovation_director.gd"


def main():
    if os.path.exists(OUT) and "--force" not in sys.argv:
        sys.exit(OUT + " exists; pass --force to overwrite it.")
    text = io.open(SRC, encoding="utf-8").read()
    blocks = re.split(r"\n(?=\[)", text)
    kept = []
    for b in blocks:
        m = re.match(r'\[node name="([^"]+)"(?: type="[^"]+")?(?: parent="([^"]*)")?', b)
        if b.startswith("[editable"):
            continue
        if m:
            name, parent = m.group(1), m.group(2) or ""
            if name in DROP or name.startswith("@Node3D@") or parent.split("/")[0] in DROP_PARENTS:
                continue
            key = name if parent in ("", ".") else parent + "/" + name
            if key in MOVE:
                basis, (x, y, z) = MOVE[key]
                tf = "transform = Transform3D(%s, %s, %s, %s)" % (basis, x, y, z)
                b = re.sub(r"transform = Transform3D\([^)]*\)", tf, b, count=1)
                assert tf in b, key
            if name in UPGRADE_ROOMS:
                b = b.rstrip("\n") + '\nroom = "%s"\n' % UPGRADE_ROOMS[name]
            if name == "RoofManager":
                b = re.sub(r"transform = Transform3D\([^)]*\)",
                           "transform = Transform3D(%s, 0.65, 1, 1.75)" % I, b)
                b = re.sub(r'roof_path = NodePath\("[^"]*"\)',
                           'roof_path = NodePath("../GrandpaShell/Roof")', b)
                b = re.sub(r"interior_extents = Vector3\([^)]*\)",
                           "interior_extents = Vector3(5.1, 1.8, 5.35)", b)
        kept.append(b)
    # prune resources nothing refers to any more (sub-resources can chain)
    while True:
        body = "\n".join(kept)
        nxt = []
        for b in kept:
            m = re.match(r'\[(ext_resource|sub_resource) [^\]]*\bid="([^"]+)"', b)
            if m:
                kind = "ExtResource" if m.group(1) == "ext_resource" else "SubResource"
                if body.count('%s("%s")' % (kind, m.group(2))) == 0:
                    continue
            nxt.append(b)
        if len(nxt) == len(kept):
            break
        kept = nxt
    out = "\n".join(kept)
    out = re.sub(r"^\[gd_scene[^\]]*\]", "[gd_scene format=3]", out)
    ext = '[ext_resource type="PackedScene" path="%s" id="gp_shell"]' % SHELL
    out = out.replace("\n[ext_resource", "\n" + ext + "\n[ext_resource", 1)
    out = out.rstrip("\n") + ('\n\n[node name="DoorSignSpot" type="Marker3D" parent="Waypoints"]\n'
                              'transform = Transform3D(%s, 0.45, 0, 6.35)\n' % I)
    for name, ext_id, basis, (x, y, z) in EXTRA:
        assert 'id="%s"' % ext_id in out, ext_id
        out = out.rstrip("\n") + (
            '\n\n[node name="%s" parent="." instance=ExtResource("%s")]\n'
            'transform = Transform3D(%s, %s, %s, %s)\n' % (name, ext_id, basis, x, y, z))
    out = out.rstrip("\n") + '\n\n[node name="GrandpaShell" parent="." instance=ExtResource("gp_shell")]\n'
    ext = '[ext_resource type="Script" path="%s" id="gp_director"]' % DIRECTOR
    out = out.replace("\n[ext_resource", "\n" + ext + "\n[ext_resource", 1)
    out = out.rstrip("\n") + ('\n\n[node name="RenovationDirector" type="Node3D" parent="."]\n'
                              'script = ExtResource("gp_director")\n')
    io.open(OUT, "w", encoding="utf-8", newline="\n").write(out)
    print("wrote", OUT, len(out) // 1024, "KB")

main()
