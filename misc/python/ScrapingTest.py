## PS> python -m pip install --upgrade pip
## PS> python -m pip install selenium
## PS> python -m pip install lxml

## import
from time import sleep
import re

from selenium import webdriver
from selenium.webdriver.chrome.options import Options

from lxml import html

## Set headless mode
config = Options()
config.add_argument("--headless")
config.add_argument("--window-size=1920x1080")
user_agent = 'MyBot/1.0'
config.add_argument('user-agent={0}'.format(user_agent))

## Launch chrome ansd open testing website
driver = webdriver.Chrome(options=config)
driver.get("https://quotes.toscrape.com/")

## Wait for contents
sleep(5)

## Get entire page sources to pass it to lxml for javascript-enabled sites
entire_src = driver.page_source

## Extract page elements using xpath
src_for_lxml = html.fromstring(entire_src)
tgt_elem = src_for_lxml.xpath("//span[contains(@class,'text') and contains(@itemprop, 'text')]")

print("Displaying fetched elements...")
print("")
print(tgt_elem)

print("")
sleep(5)

## Print targeted results
print("Displaying targeted contents...")
print("")
for e in tgt_elem:
    all_lists = e.text_content()
    print(all_lists)
    '''
    ## Extract tests
    for line in all_lists.splitlines():
        if re.search('you|miracle|thinking|better', line):
            print("Displaying results that contain specific words...")
            print(line.strip())
    '''

'''
## Get element using xpath (tested but not working)
elem = driver.find_element(By.XPATH, "//span[contains(@class,'text') and contains(@itemprop, 'text')]")
print(elem.text)
'''

sleep(10000)

## Close browser
driver.quit()
