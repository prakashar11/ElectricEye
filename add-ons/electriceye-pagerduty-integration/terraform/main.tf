#This file is part of ElectricEye.

#Licensed to the Apache Software Foundation (ASF) under one
#or more contributor license agreements.  See the NOTICE file
#distributed with this work for additional information
#regarding copyright ownership.  The ASF licenses this file
#to you under the Apache License, Version 2.0 (the
#"License"); you may not use this file except in compliance
#with the License.  You may obtain a copy of the License at

#http://www.apache.org/licenses/LICENSE-2.0

#Unless required by applicable law or agreed to in writing,
#software distributed under the License is distributed on an
#"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
#KIND, either express or implied.  See the License for the
#specific language governing permissions and limitations
#under the License.
resource "aws_lambda_function" "ElectricEye_Pagerduty_Lambda_Function" {
  filename      = "./lambda_function.zip"
  function_name = "ElectricEye-Pagerduty"
  description   = "Sends the results of high-severity ElectricEye findings to Pagerduty as incidents - Managed by Terraform"
  role          = "${aws_iam_role.ElectricEye_Pagerduty_Lambda_Role.arn}"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.8"
  memory_size   = 256
  timeout       = 61
  environment {
    variables = {
      PAGERDUTY_INTEGRATION_KEY_PARAMETER = "${var.Pagerduty_Integration_Key_Parameter}"
    }
  }
}
resource "aws_iam_role" "ElectricEye_Pagerduty_Lambda_Role" {
  name = "electriceye-Pagerduty-lambda-role"
  description = "Sends the results of high-severity ElectricEye findings to Pagerduty as incidents - Managed by Terraform"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}
resource "aws_iam_policy" "ElectricEye_Pagerduty_Lambda_Role_Policy" {
  name = "electriceye-Pagerduty-lambda-policy"
  path = "/"
  description = "Policy for ElectricEye-Pagerduty role - Managed by Terraform"
  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [ 
              "kms:Decrypt",
              "ssm:GetParameter",
              "ssm:GetParameters"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "SSM_Pagerduty_Policy_Attachment" {
  role = "${aws_iam_role.ElectricEye_Pagerduty_Lambda_Role.name}"
  policy_arn = "${aws_iam_policy.ElectricEye_Pagerduty_Lambda_Role_Policy.arn}"
}
resource "aws_iam_role_policy_attachment" "Lambda_Basic_Exec_Policy_Attachment" {
  role = "${aws_iam_role.ElectricEye_Pagerduty_Lambda_Role.name}"
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
resource "aws_cloudwatch_event_rule" "ElectricEye_Pagerduty_Event_Rule" {
  name        = "ElectricEye-Pagerduty-CWE"
  description = "Sends the results of high-severity ElectricEye findings to Pagerduty as incidents - Managed by Terraform"
  event_pattern = <<PATTERN
{
    "source": [
        "aws.securityhub"
    ],
    "detail-type": [
        "Security Hub Findings - Imported"
    ],
    "detail": {
        "findings": {
            "ProductFields": {
                "Product Name": [
                    "ElectricEye"
                ]
            },
            "Severity": {
                "Label": [
                    "HIGH",
                    "CRITICAL"
                ]
            }
        }
    }
}
PATTERN
}
resource "aws_cloudwatch_event_target" "ElectricEye_Pagerduty_Event_Rule_Lambda_Target" {
  rule      = "${aws_cloudwatch_event_rule.ElectricEye_Pagerduty_Event_Rule.name}"
  arn       = "${aws_lambda_function.ElectricEye_Pagerduty_Lambda_Function.arn}"
}
resource "aws_lambda_permission" "ElectricEye_Pagerduty_CWE_Lambda_Permission" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.ElectricEye_Pagerduty_Lambda_Function.function_name}"
  principal     = "events.amazonaws.com"
  source_arn    = "${aws_cloudwatch_event_rule.ElectricEye_Pagerduty_Event_Rule.arn}"
}