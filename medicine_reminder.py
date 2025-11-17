#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import requests
import json
import datetime
import sys
import os

def send_wechat_reminder(reminder_type="auto"):
    """
    发送企业微信机器人提醒
    """
    webhook_url = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=******************"
    
    current_time = datetime.datetime.now()
    current_hour = current_time.hour
    current_minute = current_time.minute
    time_str = current_time.strftime("%Y-%m-%d %H:%M:%S")
    
    # 定义提醒内容
    reminders = {
        "morning": {
            "title": "🌞 早上喝药提醒",
            "content": "💊 早上喝药时间到啦！记得按时喝药，开始美好的一天！",
            "time_range": "7:00-10:00"
        },
        "afternoon": {
            "title": "☀️ 下午喝药提醒",
            "content": "💊 下午喝药时间到！休息一下，记得喝药哦~",
            "time_range": "13:00-16:00"
        },
        "evening": {
            "title": "🌙 晚上喝药提醒",
            "content": "💊 晚上喝药时间！今天最后一次喝药，坚持就是胜利！",
            "time_range": "18:00-22:00"
        }
    }
    
    # 确定提醒类型
    if reminder_type == "auto":
        # 自动判断当前时间对应的提醒时间段
        if 7 <= current_hour < 10:  # 上午7-10点之间
            reminder_type = "morning"
        elif 13 <= current_hour < 16:  # 下午13-16点之间
            reminder_type = "afternoon"
        elif 18 <= current_hour < 22:  # 晚上18-22点之间
            reminder_type = "evening"
        else:
            reminder_type = "general"
    
    # 获取提醒内容
    if reminder_type in reminders:
        reminder = reminders[reminder_type]
        content = f"{reminder['content']}\n\n⏰ 提醒时间段：{reminder['time_range']}\n📅 发送时间：{time_str}"
        title = reminder['title']
    else:
        title = "💊 喝药提醒"
        content = f"💊 记得按时喝药哦~\n\n📅 发送时间：{time_str}"
    
    # 构造消息数据
    data = {
        "msgtype": "text",
        "text": {
            "content": f"{title}\n{content}",
            "mentioned_list": ["@all"]  # @所有人
        }
    }
    
    try:
        headers = {'Content-Type': 'application/json'}
        response = requests.post(webhook_url, headers=headers, data=json.dumps(data), timeout=10)
        
        if response.status_code == 200:
            result = response.json()
            if result.get('errcode') == 0:
                print(f"✅ {title} 发送成功")
                return True
            else:
                print(f"❌ 发送失败，错误码：{result.get('errcode')}, 错误信息：{result.get('errmsg')}")
                return False
        else:
            print(f"❌ 发送失败，HTTP状态码：{response.status_code}")
            return False
            
    except requests.exceptions.Timeout:
        print("❌ 请求超时，请检查网络连接")
        return False
    except requests.exceptions.ConnectionError:
        print("❌ 网络连接错误，请检查网络")
        return False
    except Exception as e:
        print(f"❌ 发送提醒时出现错误：{e}")
        return False

def main():
    """
    主函数，处理命令行参数
    """
    if len(sys.argv) > 1:
        # 如果提供了参数，使用指定的提醒类型
        reminder_type = sys.argv[1]
        send_wechat_reminder(reminder_type)
    else:
        # 没有参数，自动判断
        send_wechat_reminder("auto")

if __name__ == "__main__":
    main()
