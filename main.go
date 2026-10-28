// Loads a Go module that lives in a subdirectory of a multi-module repository
// and reports which module version the build resolved.
package main

import (
	"fmt"
	"runtime/debug"

	"github.com/aws/aws-sdk-go-v2/service/s3"
)

func main() {
	fmt.Println("s3.ServiceID:", s3.ServiceID)

	info, ok := debug.ReadBuildInfo()
	if !ok {
		return
	}
	for _, dep := range info.Deps {
		if dep.Path == "github.com/aws/aws-sdk-go-v2/service/s3" {
			fmt.Printf("resolved module: %s %s (%s)\n", dep.Path, dep.Version, dep.Sum)
		}
	}
}
