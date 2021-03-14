package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestHelloServer(t *testing.T) {
	t.Run("returns argument", func(t *testing.T) {
		request, _ := http.NewRequest(http.MethodGet, "/world", nil)
		response := httptest.NewRecorder()

		HelloServer(response, request)

		got := response.Body.String()
		want := "Hello my world!"

		if got != want {
			t.Errorf("got %q, want %q", got, want)
		}
	})
}
