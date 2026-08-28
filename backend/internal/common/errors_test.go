package common

import (
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/labstack/echo/v4"
)

func TestErrorHandler_ErrBadRequest_MapsToHTTP400(t *testing.T) {
	e := echo.New()
	e.HTTPErrorHandler = ErrorHandler

	req := httptest.NewRequest(http.MethodPost, "/test", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	// Call ErrorHandler with ErrBadRequest
	ErrorHandler(ErrBadRequest, c)

	if rec.Code != http.StatusBadRequest {
		t.Fatalf("expected status code %d, got %d", http.StatusBadRequest, rec.Code)
	}

	expectedBody := `{"error":{"code":400,"message":"Bad request"}}` + "\n"
	if rec.Body.String() != expectedBody {
		t.Fatalf("expected body %q, got %q", expectedBody, rec.Body.String())
	}
}

func TestErrorHandler_ErrNotFound_MapsToHTTP404(t *testing.T) {
	e := echo.New()
	e.HTTPErrorHandler = ErrorHandler

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	ErrorHandler(ErrNotFound, c)

	if rec.Code != http.StatusNotFound {
		t.Fatalf("expected status code %d, got %d", http.StatusNotFound, rec.Code)
	}
}

func TestErrorHandler_ErrUnauthorized_MapsToHTTP401(t *testing.T) {
	e := echo.New()
	e.HTTPErrorHandler = ErrorHandler

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	ErrorHandler(ErrUnauthorized, c)

	if rec.Code != http.StatusUnauthorized {
		t.Fatalf("expected status code %d, got %d", http.StatusUnauthorized, rec.Code)
	}
}

func TestErrorHandler_EchoHTTPError_PreservesStatusCode(t *testing.T) {
	e := echo.New()
	e.HTTPErrorHandler = ErrorHandler

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	echoErr := echo.NewHTTPError(http.StatusUnprocessableEntity, "unprocessable entity")
	ErrorHandler(echoErr, c)

	if rec.Code != http.StatusUnprocessableEntity {
		t.Fatalf("expected status code %d, got %d", http.StatusUnprocessableEntity, rec.Code)
	}
}

func TestErrorHandler_UntypedError_MapsToHTTP500(t *testing.T) {
	e := echo.New()
	e.HTTPErrorHandler = ErrorHandler

	req := httptest.NewRequest(http.MethodGet, "/test", nil)
	rec := httptest.NewRecorder()
	c := e.NewContext(req, rec)

	genericErr := errors.New("something went wrong internally")
	ErrorHandler(genericErr, c)

	if rec.Code != http.StatusInternalServerError {
		t.Fatalf("expected status code %d, got %d", http.StatusInternalServerError, rec.Code)
	}
}
