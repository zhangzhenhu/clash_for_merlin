package route

import (
	"encoding/json"
	"io/ioutil"
	"net/http"
	// "path/filepath"
    C "github.com/Dreamacro/clash/constant"
	"github.com/Dreamacro/clash/hub/executor"
	"github.com/go-chi/chi"
	"github.com/go-chi/render"
	"gopkg.in/yaml.v2"
)

// const ymlFilePath = "/path/to/your/yml/file.yml"

func ymlRouter() http.Handler {
	r := chi.NewRouter()
	r.Get("/", getYml)
	r.Get("/json", getYmlAsJson)
	r.Put("/", updateYml)
	r.Put("/json", updateYmlFromJson)
	return r
}

func getYml(w http.ResponseWriter, r *http.Request) {
	data, err := ioutil.ReadFile(C.Path.Config())
	if err != nil {
		render.Status(r, http.StatusInternalServerError)
		render.JSON(w, r, newError(err.Error()))
		return
	}
	w.Header().Set("Content-Type", "application/x-yaml")
	w.Write(data)
}

func getYmlAsJson(w http.ResponseWriter, r *http.Request) {
	data, err := ioutil.ReadFile(C.Path.Config())
	if err != nil {
		render.Status(r, http.StatusInternalServerError)
		render.JSON(w, r, newError(err.Error()))
		return
	}
	var ymlData map[interface{}]interface{}
	if err := yaml.Unmarshal(data, &ymlData); err != nil {
		render.Status(r, http.StatusInternalServerError)
		render.JSON(w, r, newError(err.Error()))
		return
	}
	jsonData := convertToStringMap(ymlData)
	render.JSON(w, r, jsonData)
}

func convertToStringMap(input map[interface{}]interface{}) map[string]interface{} {
	output := make(map[string]interface{})
	for key, value := range input {
		strKey := key.(string)
		switch value := value.(type) {
		case map[interface{}]interface{}:
			output[strKey] = convertToStringMap(value)
		case []interface{}:
			output[strKey] = convertToStringSlice(value)
		default:
			output[strKey] = value
		}
	}
	return output
}

func convertToStringSlice(input []interface{}) []interface{} {
	output := make([]interface{}, len(input))
	for i, value := range input {
		switch value := value.(type) {
		case map[interface{}]interface{}:
			output[i] = convertToStringMap(value)
		case []interface{}:
			output[i] = convertToStringSlice(value)
		default:
			output[i] = value
		}
	}
	return output
}
func updateYml(w http.ResponseWriter, r *http.Request) {
	data, err := ioutil.ReadAll(r.Body)
	if err != nil {
		render.Status(r, http.StatusBadRequest)
		render.JSON(w, r, newError(err.Error()))
		return
	}
	if _, err := executor.ParseWithBytes(data); err != nil {
		render.Status(r, http.StatusBadRequest)
		render.JSON(w, r, newError(err.Error()))
		return
	}
	if err := ioutil.WriteFile(C.Path.Config(), data, 0644); err != nil {
		render.Status(r, http.StatusInternalServerError)
		render.JSON(w, r, newError(err.Error()))
		return
	}
	render.JSON(w, r, map[string]string{"status": "success"})
}

func updateYmlFromJson(w http.ResponseWriter, r *http.Request) {
	var jsonData map[string]interface{}
	if err := json.NewDecoder(r.Body).Decode(&jsonData); err != nil {
		render.Status(r, http.StatusBadRequest)
		render.JSON(w, r, newError(err.Error()))
		return
	}
	ymlData, err := yaml.Marshal(jsonData)
	if err != nil {
		render.Status(r, http.StatusInternalServerError)
		render.JSON(w, r, newError(err.Error()))
		return
	}
	if _, err := executor.ParseWithBytes(ymlData); err != nil {
		render.Status(r, http.StatusBadRequest)
		render.JSON(w, r, newError(err.Error()))
		return
	}
	if err := ioutil.WriteFile(C.Path.Config(), ymlData, 0644); err != nil {
		render.Status(r, http.StatusInternalServerError)
		render.JSON(w, r, newError(err.Error()))
		return
	}
	render.JSON(w, r, map[string]string{"status": "success"})
}
