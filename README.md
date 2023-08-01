# Azure DevOps Pull Request GPT

This project utilizes Azure OpenAI to review pull requests and offer suggestions. At present, Azure OpenAI is supported.

Here's how to use it:

1. Open a Powershell command line window and navigate to the directory containing your Azure DevOps repository.
2. Execute the command below:

```powershell
Invoke-CodeReviewWithChatGPT.ps1 -Organization <Organization> -Project <Organization> -PullRequestId <PullRequestId> -PAT <PAT> -ChatGPTAccountName <ChatGPTAccountName> -ChatGPTAccessKey <ChatGPTAccessKey> -ChatGPTDeploymentName <ChatGPTDeploymentName>
```