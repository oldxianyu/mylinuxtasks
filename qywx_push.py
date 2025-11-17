#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import requests
import json
import datetime
import time
import sys
import os


# =====================================================
# ✅ 节假日与周末倒计时模块
# =====================================================
class HolidayCountdown:
    def __init__(self):
        self.current_date = datetime.date.today()
        self.current_year = self.current_date.year

        self.fallback_holidays = {
            "2026": {
                "2026-01-01": {"name": "元旦", "isOffDay": True},
                "2026-02-17": {"name": "春节", "isOffDay": True},
                "2026-05-01": {"name": "劳动节", "isOffDay": True},
                "2026-06-19": {"name": "端午节", "isOffDay": True},
                "2026-09-25": {"name": "中秋节", "isOffDay": True},
                "2026-10-01": {"name": "国庆节", "isOffDay": True},
            }
        }

    def get_holidays_data(self, year):
        try:
            url = f"https://api.jiejiariapi.com/v1/holidays/{year}"
            res = requests.get(url, timeout=10)
            res.raise_for_status()
            print(f"[INFO] {year}年节假日数据获取成功")
            return res.json()
        except Exception:
            print(f"[WARN] {year}年节假日API获取失败，使用本地数据")
            return self.fallback_holidays.get(str(year), {})

    def get_future_holidays(self):
        holidays = {}
        for year in [self.current_year, self.current_year + 1]:
            data = self.get_holidays_data(year)
            for d, info in data.items():
                try:
                    date_obj = datetime.datetime.strptime(d, "%Y-%m-%d").date()
                    if year == self.current_year and date_obj < self.current_date:
                        continue
                    holidays[d] = info
                except Exception:
                    continue
        print("[INFO] 节假日信息处理完成")
        return holidays

    def get_nearest_rest_days(self, days_range=365):
        rest_days = []
        holidays_data = self.get_future_holidays()
        found_saturday = found_sunday = found_holiday = False

        for i in range(days_range):
            target = self.current_date + datetime.timedelta(days=i)
            date_str = target.strftime("%Y-%m-%d")

            if not found_holiday and date_str in holidays_data:
                info = holidays_data[date_str]
                if info.get("isOffDay", False):
                    rest_days.append((i, info["name"], target))
                    found_holiday = True

            if not found_saturday and target.weekday() == 5:
                rest_days.append((i, "周六", target))
                found_saturday = True

            if not found_sunday and target.weekday() == 6:
                rest_days.append((i, "周日", target))
                found_sunday = True

            if found_holiday and found_saturday and found_sunday:
                break

        rest_days.sort(key=lambda x: x[0])
        return rest_days

    def format_rest_days_output(self):
        lines = []
        rest_days = self.get_nearest_rest_days()
        for i, name, date_obj in rest_days:
            date_str = date_obj.strftime("%Y年%m月%d日")
            lines.append(f"⏳ 距离{name}还有{i}天（{date_str}）")
        return "\n".join(lines)


# =====================================================
# ✅ 企业微信机器人模块
# =====================================================
class WeComRobot:
    def __init__(self, webhook_urls):
        if isinstance(webhook_urls, str):
            self.webhook_urls = [webhook_urls]
        else:
            self.webhook_urls = webhook_urls

    def send_markdown(self, content):
        data = {"msgtype": "markdown", "markdown": {"content": content}}
        return self._send_message_to_all(data)

    def _send_message(self, data, webhook_url):
        headers = {'Content-Type': 'application/json'}
        try:
            res = requests.post(webhook_url, headers=headers, data=json.dumps(data), timeout=10)
            result = res.json()
            if result.get('errcode') == 0:
                return True, None
            else:
                return False, f"发送失败: {result}"
        except Exception as e:
            return False, f"发送异常: {e}"

    def _send_message_to_all(self, data):
        success, fail, errors = 0, 0, []
        for url in self.webhook_urls:
            ok, err = self._send_message(data, url)
            if ok:
                print(f"[INFO] 企业微信推送成功: {url}")
                success += 1
            else:
                print(f"[ERROR] 企业微信推送失败: {url}")
                fail += 1
                if err:
                    errors.append(err)
            time.sleep(0.5)
        return success, fail, errors


# =====================================================
# ✅ 新闻与历史模块
# =====================================================
def get_daily_news():
    url = "http://10.1.1.140:4399/v2/60s"
    print("[INFO] 正在获取每日新闻...")
    try:
        res = requests.get(url, timeout=10)
        if res.status_code == 200:
            result = res.json()
            if result.get("code") == 200:
                print("[INFO] 每日新闻获取成功")
                return result.get("data")
    except Exception:
        print("[WARN] 每日新闻接口获取失败")
    return None


def get_today_in_history():
    url = "http://10.1.1.140:4399/v2/today-in-history"
    print("[INFO] 正在获取历史上的今天...")
    try:
        res = requests.get(url, timeout=10)
        if res.status_code == 200:
            result = res.json()
            if result.get("code") == 200:
                print("[INFO] 历史上的今天获取成功")
                return result.get("data")
    except Exception:
        print("[WARN] 历史上的今天接口获取失败")
    return None


# =====================================================
# ✅ 消息格式化（分隔符改为⭐）
# =====================================================
def format_history_message(history_data):
    if not history_data:
        return ""
    items = history_data.get('items', [])
    if not items:
        return ""
    content = "## 📅 历史上的今天\n\n"
    for item in items[:5]:
        year = item.get('year', '')
        title = item.get('title', '')
        content += f"📘 **{year}年** - {title}\n\n"
    return content


def format_news_message(news_data, history_content, holiday_content):
    if not news_data:
        return "今日新闻获取失败。"
    date = news_data.get('date', '未知日期')
    news_list = news_data.get('news', [])
    content = f"## 📰 每日新闻简报 {date}\n\n"
    for i, item in enumerate(news_list[:10], 1):
        content += f"{i}. {item}\n\n"
    # ⭐ 改为星号分隔符
    if history_content:
        content += " \n" + history_content + "\n"
    if holiday_content:
        content += " \n" + holiday_content + "\n"
    return content


# =====================================================
# ✅ 主程序
# =====================================================
def main():
    print("[INFO] 开始执行每日简报任务")

    webhook_urls = [
        "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=***********************************",
        "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=***********************************"
    ]

    news_data = get_daily_news()
    history_data = get_today_in_history()

    countdown = HolidayCountdown()
    holiday_output = countdown.format_rest_days_output()

    history_content = format_history_message(history_data)
    message_content = format_news_message(news_data, history_content, holiday_output)

    robot = WeComRobot(webhook_urls)
    success, fail, errors = robot.send_markdown(message_content)

    if fail > 0 or errors:
        print(f"[❌] 消息推送失败: 成功 {success}, 失败 {fail}")
        for e in errors:
            print(f" - {e}")
    else:
        print("[INFO] 所有企业微信推送完成")

    print("[INFO] 任务执行完毕\n")


if __name__ == "__main__":
    try:
        main()
    except Exception as e:
        print(f"[⚠️ 程序异常终止] {e}")
