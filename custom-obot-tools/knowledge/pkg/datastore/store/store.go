package store

import (
	"context"

	"github.com/jrmatherly/obot-entraid/custom-obot-tools/knowledge/pkg/index/types"
	vs "github.com/jrmatherly/obot-entraid/custom-obot-tools/knowledge/pkg/vectorstore/types"
)

type Store interface {
	ListDatasets(ctx context.Context) ([]types.Dataset, error)
	GetDataset(ctx context.Context, datasetID string, opts *types.DatasetGetOpts) (*types.Dataset, error)
	SimilaritySearch(ctx context.Context, query string, numDocuments int, collection string, where map[string]string, whereDocument []vs.WhereDocument) ([]vs.Document, error)
	GetDocuments(ctx context.Context, datasetID string, where map[string]string, whereDocument []vs.WhereDocument) ([]vs.Document, error)
}
