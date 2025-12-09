package types

import (
	vs "github.com/jrmatherly/obot-entraid/custom-obot-tools/knowledge/pkg/vectorstore/types"
)

type EmbeddingModelProvider interface {
	Name() string
	EmbeddingFunc() (vs.EmbeddingFunc, error)
	Configure() error
	Config() any
	EmbeddingModelName() string
	UseEmbeddingModel(model string)
}
