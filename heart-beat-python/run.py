"""
Usage:
    run.py monitor.ini
"""
import sys
from monitor import HeartBeatMonitor


def main():
    monitor = HeartBeatMonitor('heart-beat-monitor', sys.argv[1:])
    monitor.start()


if __name__ == '__main__':
    main()
