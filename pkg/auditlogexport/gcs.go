package auditlogexport

import (
	"context"
	"fmt"
	"io"

	"cloud.google.com/go/storage"
	"github.com/obot-platform/obot/apiclient/types"
	"golang.org/x/oauth2/google"
	"google.golang.org/api/option"
)

// GCSProvider implements StorageProvider for Google Cloud Storage
type GCSProvider struct {
	credProvider CredentialProvider
}

// NewGCSProvider creates a new GCS storage provider
func NewGCSProvider(credProvider CredentialProvider) *GCSProvider {
	return &GCSProvider{
		credProvider: credProvider,
	}
}

func (g *GCSProvider) Upload(ctx context.Context, config types.StorageConfig, bucket, key string, data io.Reader) error {
	client, err := g.createClient(ctx, config)
	if err != nil {
		return err
	}
	defer client.Close()

	bucketHandle := client.Bucket(bucket)
	obj := bucketHandle.Object(key)

	writer := obj.NewWriter(ctx)

	_, err = io.Copy(writer, data)
	if err != nil {
		writer.Close()
		return err
	}
	return writer.Close()
}

func (g *GCSProvider) Test(ctx context.Context, config types.StorageConfig) error {
	client, err := g.createClient(ctx, config)
	if err != nil {
		return fmt.Errorf("invalid GCS credentials: %w", err)
	}
	defer client.Close()

	return nil
}

func (g *GCSProvider) createClient(ctx context.Context, config types.StorageConfig) (*storage.Client, error) {
	gcsConfig := config.GCSConfig
	if gcsConfig == nil {
		return nil, fmt.Errorf("GCS configuration is required")
	}

	if gcsConfig.ServiceAccountJSON != "" {
		creds, err := google.CredentialsFromJSON(ctx, []byte(gcsConfig.ServiceAccountJSON), storage.ScopeReadWrite)
		if err != nil {
			return nil, fmt.Errorf("failed to create credentials from JSON: %w", err)
		}
		return storage.NewClient(ctx, option.WithCredentials(creds))
	}

	return storage.NewClient(ctx)
}
