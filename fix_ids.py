import re
import uuid

with open("/Users/sdc-user/MITWPU-Group20-SkyTrails/SkyTrails/SkyTrails/Watchlist/View/Watchlist.storyboard", "r") as f:
    content = f.read()

# Replace duplicate Date-Info-Btn and Location-Info-Btn IDs with unique ones
def generate_id():
    return str(uuid.uuid4())[:10]

def replacer(match):
    return match.group(0).replace('id="' + match.group(1) + '"', 'id="' + match.group(1) + '-' + generate_id() + '"')

content = re.sub(r'id="(Date-Info-Btn)"', replacer, content)
content = re.sub(r'id="(Location-Info-Btn)"', replacer, content)

with open("/Users/sdc-user/MITWPU-Group20-SkyTrails/SkyTrails/SkyTrails/Watchlist/View/Watchlist.storyboard", "w") as f:
    f.write(content)
