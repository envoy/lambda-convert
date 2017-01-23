# lambda-convert
AWS Lambda powered drop-in replacement for ImageMagick convert command line tool

## Background

At Envoy, we have many image file uploaded by users and will be resized via `convert` (ImageMagick) command line tool. It works fine, the only problems are

### Dealing with big GIF image

When user upload a GIF image, to resize it, ImageMagick will need to load the all frames into memory. In that case, even the GIF image file is very small, could posiblly consume huge amount of memory. This brings big impact to our API server, and sometimes the uploading request fails due to this reason.

### Security concern

Despite it's not really easy to perform, it still possible to leverage exploits of certain image file format loading code in ImageMagick.

## Solution

To eliminate the big image file uploading issue and the security risk, the idea here is to do image resizing on AWS Lambda instead of localhost. This command line tool is a drop-in replacement for `convert` command, except it upload the input image file to S3, does the resizing on AWS Lambda and finally down the result image back to localhost.

## Environment variables
