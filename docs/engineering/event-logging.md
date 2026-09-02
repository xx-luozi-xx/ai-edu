# 事件日志设计

## 通用字段

| 字段 | 说明 |
|---|---|
| event_id | 事件唯一标识 |
| participant_id | 匿名参与者编号 |
| session_id | 学习会话编号 |
| task_id | 任务编号 |
| condition_id | 实验条件编号 |
| event_type | 事件类型 |
| server_timestamp | 服务端时间 |
| elapsed_time_ms | 从任务开始计算的时间 |
| config_version | 实验配置版本 |

## 候选事件

- task_started
- answer_edited
- answer_submitted
- confidence_reported
- help_requested
- help_triggered
- help_displayed
- verification_submitted
- reflection_submitted
- task_completed

## AI帮助字段

- help_id；
- trigger_type；
- trigger_reason；
- help_level；
- help_format；
- attempt_count_before_help；
- elapsed_time_before_help_ms；
- prompt_version；
- model_version。
