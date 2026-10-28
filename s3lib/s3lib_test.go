package s3lib

import (
	"context"
	"net/http"
	"net/http/httptest"
	"slices"
	"testing"
)

// listBucketsResponse is a minimal S3 ListBuckets reply.
const listBucketsResponse = `<?xml version="1.0" encoding="UTF-8"?>
<ListAllMyBucketsResult xmlns="http://s3.amazonaws.com/doc/2006-03-01/">
  <Buckets>
    <Bucket><Name>first</Name><CreationDate>2026-01-01T00:00:00.000Z</CreationDate></Bucket>
    <Bucket><Name>second</Name><CreationDate>2026-01-02T00:00:00.000Z</CreationDate></Bucket>
  </Buckets>
</ListAllMyBucketsResult>`

// TestListBucketNames runs the real S3 client against a local fake S3
// endpoint, so it needs no network access or AWS account.
func TestListBucketNames(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.Method != http.MethodGet || r.URL.Path != "/" {
			t.Errorf("unexpected request %s %s", r.Method, r.URL.Path)
		}
		w.Header().Set("Content-Type", "application/xml")
		w.Write([]byte(listBucketsResponse))
	}))
	defer server.Close()

	names, err := ListBucketNames(context.Background(), server.URL)
	if err != nil {
		t.Fatalf("ListBucketNames: %v", err)
	}
	if want := []string{"first", "second"}; !slices.Equal(names, want) {
		t.Fatalf("got %v, want %v", names, want)
	}
}
