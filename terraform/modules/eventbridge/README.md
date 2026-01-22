# EventBridge Module

Terraform module for creating an Amazon EventBridge rule to schedule execution of Step Functions state machines.

## Features

- Cron-based scheduling for automated pipeline execution
- Enable/disable schedule without destroying resources
- IAM role for EventBridge to invoke Step Functions
- Flexible schedule expressions (cron or rate)

## Usage

```hcl
module "eventbridge" {
  source = "./modules/eventbridge"
  
  project_name = "nasdaq-equity-batch-pipeline"
  environment  = "dev"
  rule_name    = "nasdaq-equity-batch-pipeline-daily-trigger-dev"
  
  # Schedule configuration
  schedule_expression = "cron(30 10 * * ? *)"  # 6:30 PM SGT daily
  enabled             = false  # Start disabled for testing
  
  # Target: Step Functions State Machine
  target_arn             = module.step_functions.state_machine_arn
  state_machine_role_arn = module.step_functions.execution_role_arn
  
  tags = {
    Project     = "nasdaq-equity-batch-pipeline"
    Environment = "dev"
  }
}
```

## Schedule Expressions

### Cron Format
```
cron(Minutes Hours Day-of-month Month Day-of-week Year)
```

**Examples:**
- `cron(30 10 * * ? *)` - 6:30 PM SGT daily (10:30 UTC)
- `cron(0 12 * * ? *)` - 8:00 PM SGT daily (12:00 UTC)
- `cron(0 0 * * MON *)` - 8:00 AM SGT every Monday
- `cron(0 2 1 * ? *)` - 10:00 AM SGT on 1st of each month

### Rate Format
```
rate(value unit)
```

**Examples:**
- `rate(1 hour)` - Every hour
- `rate(12 hours)` - Every 12 hours
- `rate(1 day)` - Every day
- `rate(7 days)` - Every week

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| project_name | Name of the project | string | - | yes |
| environment | Environment name | string | - | yes |
| rule_name | Name of EventBridge rule | string | - | yes |
| schedule_expression | Cron or rate expression | string | - | yes |
| enabled | Enable the rule | bool | false | no |
| target_arn | Step Functions ARN | string | - | yes |
| state_machine_role_arn | Step Functions role ARN | string | - | yes |
| tags | Resource tags | map(string) | {} | no |

## Outputs

| Name | Description |
|------|-------------|
| rule_arn | ARN of the EventBridge rule |
| rule_name | Name of the EventBridge rule |
| target_id | ID of the EventBridge target |
| invoke_role_arn | ARN of the invoke role |
| schedule_expression | The schedule expression |
| is_enabled | Whether the rule is enabled |

## Enabling/Disabling the Schedule

### Method 1: Terraform Variable
```hcl
# terraform.tfvars
orchestration_schedule_enabled = true  # Enable
orchestration_schedule_enabled = false # Disable
```

Then apply:
```bash
terraform apply
```

### Method 2: AWS CLI
```bash
# Enable
aws events enable-rule --name nasdaq-equity-batch-pipeline-daily-trigger-dev

# Disable
aws events disable-rule --name nasdaq-equity-batch-pipeline-daily-trigger-dev
```

### Method 3: Provided Script
```bash
cd scripts

# Enable schedule
./orchestrate_pipeline.sh enable

# Disable schedule
./orchestrate_pipeline.sh disable
```

## Timezone Considerations

EventBridge uses UTC time. Singapore is UTC+8.

**Conversion:**
- 6:00 PM SGT = 10:00 AM UTC = `cron(0 10 * * ? *)`
- 6:30 PM SGT = 10:30 AM UTC = `cron(30 10 * * ? *)`
- 8:00 PM SGT = 12:00 PM UTC = `cron(0 12 * * ? *)`

## Monitoring

View EventBridge rules in AWS Console:
```
https://console.aws.amazon.com/events/home?region=your-region#/rules
```

Check execution history:
```bash
aws events list-rule-names-by-target \
  --target-arn arn:aws:states:region:account:stateMachine:name
```

## Best Practices

1. **Start Disabled** - Create rule with `enabled = false`, test manually first
2. **Test Schedule** - Use `cron(*/5 * * * ? *)` (every 5 min) for testing
3. **Production Schedule** - Use daily/weekly schedules for production
4. **Monitor Costs** - Frequent execution = higher AWS costs

## Example: Development to Production

**Development:**
```hcl
schedule_expression = "cron(*/15 * * * ? *)"  # Every 15 min for testing
enabled             = false  # Manual testing only
```

**Staging:**
```hcl
schedule_expression = "cron(0 */2 * * ? *)"  # Every 2 hours
enabled             = true   # Automated testing
```

**Production:**
```hcl
schedule_expression = "cron(30 10 * * ? *)"  # Daily at 6:30 PM SGT
enabled             = true   # Full automation
```
