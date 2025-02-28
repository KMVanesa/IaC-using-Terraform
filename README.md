# Terraform

## Installation

The latest version can be installed using `go get`:

``` bash
GO111MODULE="on" go get github.com/segmentio/terraform-docs@v0.9.1
```

If you are a Mac OS X user, you can use Homebrew:

``` bash
brew install terraform
```

## Code Completion

The code completion for `bash` can be installed using:


### bash

``` bash
terraform-docs completion bash > ~/.terraform-docs-completion
source ~/.terraform-docs-completion
```

## Plan and Apply the Terraform Files

Export AWS Credentials, execute following:

``` bash
terraform plan main.tf
```

and run this :

``` bash
terraform apply main.tf
```

## Upload SSL Certificate to AWS certificate manager use foll0wing command:
```bash
aws acm import-certificate --certificate file://<your_certicate_path> --private-key file://<your_private_key_path> --certificate-chain file://<your_certicate_bundle_path>
```
