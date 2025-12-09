package transformers

import (
	"context"

	vs "github.com/jrmatherly/obot-entraid/custom-obot-tools/knowledge/pkg/vectorstore/types"
)

type GenericTransformer struct {
	TransformationFunc func(context.Context, []vs.Document) ([]vs.Document, error)
}

func (g *GenericTransformer) Transform(ctx context.Context, docs []vs.Document) ([]vs.Document, error) {
	return g.TransformationFunc(ctx, docs)
}
