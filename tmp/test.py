import time 
from tqdm import tqdm 
import argparse 
import random

if __name__=='__main__': 
    parser = argparse.ArgumentParser() 
    parser.add_argument('--time', type=str, default='20:00:00') 
    args = parser.parse_args() 
    
    k = random.random() - 0.5
    hours, minutes, seconds = list(map(int, args.time.split(':'))) 
    length = (hours*60 + minutes) * 60 + seconds 
    
    for i in tqdm(range(length)): 
        k += random.random() - 0.5
        time.sleep(1)
