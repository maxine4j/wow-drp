from PIL import ImageGrab
import pypresence
import time
import logging

from data import large_image_instanceMapID, name_classID, large_image_mapID, large_image_zone, small_image_classID

# config
discord_client_id = '429296102727221258'  # Put your Client ID here
msg_header = "ARW"
max_msg_len = 900


# reads message character by character using all 3 color channels
def parse_pixels(pixels):
    msg = ""
    for p in pixels:
        r, g, b = p
        if r != 0:
            msg += chr(r)
    for p in pixels:
        r, g, b = p
        if g != 0:
            msg += chr(g)
    for p in pixels:
        r, g, b = p
        if b != 0:
            msg += chr(b)
    return msg


# gets pixel data from screenshot
def read_screen():
    img = ImageGrab.grab(bbox=(0, 0, max_msg_len / 3, 1))
    pixels = list(img.getdata())
    return pixels


def get_msg():
    px = read_screen()
    msg = parse_pixels(px)
    if msg[:3] != msg_header:
        return None
    return msg[3:]


def parse_msg(msg):
    ms = msg.split("|")
    i = 0
    data = dict()
    data["name"] = ms[i]; i+=1
    data["realm"] = ms[i]; i+=1
    data["classID"] = int(ms[i]); i+=1
    data["race"] = ms[i]; i+=1
    data["level"] = int(ms[i]); i+=1
    data["mapAreaID"] = int(ms[i]); i+=1
    data["instanceMapID"] = int(ms[i]); i+=1
    data["zone"] = ms[i]; i+=1
    data["miniMapZoneText"] = ms[i]; i+=1
    data["numGroupMembers"] = ms[i]; i+=1
    data["inRaidGroup"] = bool(int(ms[i])); i+=1
    data["status"] = ms[i]; i+=1
    data["timeStarted"] = int(float(ms[i])); i+=1
    return data


def format_state(data):
    return data["status"]


def format_details(data):
    return "%s - %s" % (data["name"], data["realm"])


def format_large_text(data):
    if data["classID"] == 4 and data["level"] > 97 and data["miniMapZoneText"] in large_image_zone:
        return "The Hall of Shadows"
    return data["zone"]


def format_large_image(data):
    try:  # check for rogue class hall
        if data["classID"] == 4 and data["level"] > 97:
            return large_image_zone[data["miniMapZoneText"]]
    except: pass
    try:  # check for other class halls
        if data["level"] > 97:
            return large_image_zone[data["zone"]]
    except: pass
    try:  # check for cities
        return large_image_mapID[data["mapID"]]
    except: pass
    try:  # check for dungeons and raids
        return large_image_instanceMapID[data["instanceMapID"]]
    except: pass
    # default
    return "cont_azeroth"


def format_small_text(data):
    race = data["race"]
    if race == "NightElf":
        race = "Night Elf"
    elif race == "BloodElf":
        race = "Blood Elf"
    elif race == "VoidElf":
        race = "Void Elf"
    elif race == "LightforgedDraenei":
        race = "Lightforged Draenei"
    elif race == "HighmountainTauren":
        race = "Highmountain Tauren"
    return "%d %s %s" % (data["level"], race, name_classID[data["classID"]])


def format_small_image(data):
    try:
        return small_image_classID[data["classID"]]
    except:
        return "icon_full"


def format_start(data):
    return None
    #if data["timeStarted"] != -1:
    #    return data["timeStarted"]


def format_party_size(data):
    return None
    #if data["groupSize"] == 0:
    #    return None
    #return data["groupSize"]


def format_party_max(data):
    return None
    #if data["groupSize"] == 0:
    #    return None
    #if data["inRaidGroup"]:
    #    return 20
    #return 5


def start_drp():
    rpc = pypresence.client(discord_client_id)
    rpc.start()
    last_msg = ""
    while True:  # The presence will stay on as long as the program is running
        try:
            msg = get_msg()
            if msg and last_msg != msg:
                print("Raw Msg: " + msg)
                data = parse_msg(msg)
                rpc.set_activity(state=format_state(data),
                                 details=format_details(data),
                                 start=format_start(data),
                                 large_image=format_large_image(data),
                                 large_text=format_large_text(data),
                                 small_image=format_small_image(data),
                                 small_text=format_small_text(data),
                                 party_size=format_party_size(data),
                                 party_max=format_party_max(data))
                last_msg = msg
        except Exception as e:
            logging.exception("Exception in Main Loop")
            print("Exception: " + str(e))
        time.sleep(1)

start_drp()
