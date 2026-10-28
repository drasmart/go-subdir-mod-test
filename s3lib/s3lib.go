// Package s3lib wraps a call to the S3 API from the subdirectory module
// github.com/aws/aws-sdk-go-v2/service/s3.
package s3lib

import (
	"context"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/service/s3"
)

// ListBucketNames calls the S3 ListBuckets API at endpoint and returns the
// bucket names. Requests are unsigned, so no AWS credentials are needed.
func ListBucketNames(ctx context.Context, endpoint string) ([]string, error) {
	client := s3.New(s3.Options{
		Region:           "us-east-1",
		BaseEndpoint:     aws.String(endpoint),
		Credentials:      aws.AnonymousCredentials{},
		UsePathStyle:     true,
		RetryMaxAttempts: 1,
	})
	out, err := client.ListBuckets(ctx, &s3.ListBucketsInput{})
	if err != nil {
		return nil, err
	}
	names := make([]string, 0, len(out.Buckets))
	for _, b := range out.Buckets {
		names = append(names, aws.ToString(b.Name))
	}
	return names, nil
}
