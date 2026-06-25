using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Threading.Tasks;

namespace MCAppsTools.Services
{
    public enum StepStatus
    {
        Pending,
        Running,
        Completed,
        Failed
    }

    public class WorkflowStep
    {
        public string Name { get; set; } = string.Empty;
        public StepStatus Status { get; set; } = StepStatus.Pending;

        public WorkflowStep(string name)
        {
            Name = name;
        }
    }

    public class MockWorkflowService
    {
        private static MockWorkflowService? _instance;
        public static MockWorkflowService Shared => _instance ??= new MockWorkflowService();

        // Valid key regex based on macOS signed key format:
        // XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXX-XXXXXXXX (with routing signature at the end)
        private static readonly Regex KeyRegex = new(
            @"^[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{6}-[0-9A-Fa-f]{8}$",
            RegexOptions.Compiled
        );

        public bool ValidateKeyFormat(string key)
        {
            if (string.IsNullOrWhiteSpace(key)) return false;
            return KeyRegex.IsMatch(key.Trim());
        }

        public async Task<bool> RunActivationWorkflow(
            string key,
            List<WorkflowStep> steps,
            Action<int> onStepChanged
        )
        {
            // Reset steps to Pending
            foreach (var step in steps)
            {
                step.Status = StepStatus.Pending;
            }

            try
            {
                // Step 1: Validating License
                steps[0].Status = StepStatus.Running;
                onStepChanged(0);
                await Task.Delay(1500); // Simulate network latency
                steps[0].Status = StepStatus.Completed;
                onStepChanged(0);

                // Step 2: Downloading Release
                steps[1].Status = StepStatus.Running;
                onStepChanged(1);
                await Task.Delay(2500); // Simulate package download
                steps[1].Status = StepStatus.Completed;
                onStepChanged(1);

                // Step 3: Installing Plugin
                steps[2].Status = StepStatus.Running;
                onStepChanged(2);
                await Task.Delay(2000); // Simulate extraction & elevated writing to Program Files
                steps[2].Status = StepStatus.Completed;
                onStepChanged(2);

                // Step 4: Activating license on this machine
                steps[3].Status = StepStatus.Running;
                onStepChanged(3);
                await Task.Delay(1500); // Simulate LexActivator local activation call
                steps[3].Status = StepStatus.Completed;
                onStepChanged(3);

                return true;
            }
            catch (Exception)
            {
                // Set any running step to Failed
                foreach (var step in steps)
                {
                    if (step.Status == StepStatus.Running)
                    {
                        step.Status = StepStatus.Failed;
                    }
                }
                return false;
            }
        }
    }
}
