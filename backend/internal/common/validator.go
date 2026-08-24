package common

import (
	"regexp"

	"github.com/go-playground/validator/v10"
	"github.com/google/uuid"
)

// CustomValidator struct implementing echo.Validator.
type CustomValidator struct {
	validator *validator.Validate
}

// NewValidator initializes and returns a custom validator.
func NewValidator() *CustomValidator {
	v := validator.New()

	// Register custom validation rules
	v.RegisterValidation("phone", validatePhoneE164)
	v.RegisterValidation("uuid", validateUUID)

	return &CustomValidator{validator: v}
}

// Validate validates the given struct using the configured validator rules.
func (cv *CustomValidator) Validate(i interface{}) error {
	if err := cv.validator.Struct(i); err != nil {
		return err
	}
	return nil
}

// validatePhoneE164 ensures the string matches E.164 phone number format.
func validatePhoneE164(fl validator.FieldLevel) bool {
	phone := fl.Field().String()
	// E.164 format: ^\+[1-9]\d{1,14}$
	re := regexp.MustCompile(`^\+[1-9]\d{1,14}$`)
	return re.MatchString(phone)
}

// validateUUID ensures the string is a valid UUID.
func validateUUID(fl validator.FieldLevel) bool {
	u := fl.Field().String()
	_, err := uuid.Parse(u)
	return err == nil
}
