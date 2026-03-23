import re

with open("/Users/sdc-user/MITWPU-Group20-SkyTrails/SkyTrails/SkyTrails/Watchlist/View/Watchlist.storyboard", "r") as f:
    content = f.read()

# For Date
date_header_pattern = r'''(<label opaque="NO" userInteractionEnabled="NO" contentMode="left" horizontalHuggingPriority="251" verticalHuggingPriority="251" text="Date".*?</label>)'''
date_header_replacement = r'''\1
                                                    <button opaque="NO" contentMode="scaleToFill" contentHorizontalAlignment="center" contentVerticalAlignment="center" buttonType="system" lineBreakMode="middleTruncation" translatesAutoresizingMaskIntoConstraints="NO" id="Date-Info-Btn">
                                                        <rect key="frame" x="51.666666666666657" y="0.0" width="31" height="31"/>
                                                        <state key="normal" title="Button"/>
                                                        <buttonConfiguration key="configuration" style="plain" image="info.circle" catalog="system"/>
                                                        <connections>
                                                            <action selector="didTapDateInfo" destination="6Sg-aR-vKV" eventType="touchUpInside"/>
                                                        </connections>
                                                    </button>'''
content = re.sub(date_header_pattern, date_header_replacement, content, flags=re.DOTALL)

# For Location
location_header_pattern = r'''(<label opaque="NO" userInteractionEnabled="NO" contentMode="left" horizontalHuggingPriority="251" verticalHuggingPriority="251" text="Location".*?</label>)'''
location_header_replacement = r'''\1
                                                    <button opaque="NO" contentMode="scaleToFill" contentHorizontalAlignment="center" contentVerticalAlignment="center" buttonType="system" lineBreakMode="middleTruncation" translatesAutoresizingMaskIntoConstraints="NO" id="Location-Info-Btn">
                                                        <rect key="frame" x="87" y="0.0" width="31" height="31"/>
                                                        <state key="normal" title="Button"/>
                                                        <buttonConfiguration key="configuration" style="plain" image="info.circle" catalog="system"/>
                                                        <connections>
                                                            <action selector="didTapLocationInfo" destination="6Sg-aR-vKV" eventType="touchUpInside"/>
                                                        </connections>
                                                    </button>'''
content = re.sub(location_header_pattern, location_header_replacement, content, flags=re.DOTALL)


with open("/Users/sdc-user/MITWPU-Group20-SkyTrails/SkyTrails/SkyTrails/Watchlist/View/Watchlist.storyboard", "w") as f:
    f.write(content)
