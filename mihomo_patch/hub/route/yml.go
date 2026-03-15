package route

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	// "net/http"
	// "path/filepath"
    C "github.com/metacubex/mihomo/constant"
	"github.com/metacubex/mihomo/log"
	"github.com/metacubex/mihomo/hub/executor"
	"github.com/metacubex/chi"
	"github.com/metacubex/chi/render"
	"github.com/metacubex/http"
	// "github.com/go-chi/chi"
	// "github.com/go-chi/render"
	"gopkg.in/yaml.v3"
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
	// 添加调试输出
	// fmt.Println("Debug: getYml function called")

	data, err := ioutil.ReadFile(C.Path.Config())
	if err != nil {
		render.Status(r, http.StatusInternalServerError)
		render.JSON(w, r, newError(err.Error()))
		fmt.Printf("Error [getYml] 配置信息读取错误: %s\n", err)
		log.Errorln("[getYml] 配置信息读取错误: %s", err)
		return
	}
	fmt.Printf("Info [getYml] 读取配置信息完成，大小: %d 字节\n", len(data))
	log.Errorln("[getYml] 读取配置信息完成，大小: %d 字节", len(data))
	w.Header().Set("Content-Type", "application/x-yaml")
	w.Write(data)
}

func getYmlAsJson(w http.ResponseWriter, r *http.Request) {
	// 添加调试输出
	// fmt.Println("Debug: getYmlAsJson function called")

	data, err := ioutil.ReadFile(C.Path.Config())
	if err != nil {
		render.Status(r, http.StatusInternalServerError)
		render.JSON(w, r, newError(err.Error()))
		log.Errorln("[getYmlAsJson] 配置信息读取错误: %s", err)
		return
	}
	// fmt.Printf("Info [getYml] 读取配置信息完成，大小: %d 字节\n", len(data))
	log.Infoln("[getYmlAsJson] 读取配置信息完成，大小: %d 字节", len(data))
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
	// 添加调试输出
	fmt.Println("Debug: updateYml function called")

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
	fmt.Println("Info: 配置更新成功")
	log.Infoln("Info: 配置更新成功")
	render.JSON(w, r, map[string]string{"status": "success"})
}

func updateYmlFromJson(w http.ResponseWriter, r *http.Request) {
	// 添加调试输出
	// fmt.Println("Debug: updateYmlFromJson function called")

	var jsonData map[string]interface{}
	// fmt.Println("Info [updateYmlFromJson] 接收到配置信息")

	if err := json.NewDecoder(r.Body).Decode(&jsonData); err != nil {
		render.Status(r, http.StatusBadRequest)
		render.JSON(w, r, newError(err.Error()))
		fmt.Printf("Error [updateYmlFromJson] 错误信息: %s\n", err)
		log.Infoln("[updateYmlFromJson] 错误信息: %s", err)
		return
	}
	log.Infoln("[updateYmlFromJson] 接收到配置信息: %s", jsonData)

	ymlData, err := yaml.Marshal(jsonData)
	if err != nil {
		render.Status(r, http.StatusInternalServerError)
		render.JSON(w, r, newError(err.Error()))
		log.Errorln("[updateYmlFromJson] yaml错误: %s", err)
		return
	}
	if _, err := executor.ParseWithBytes(ymlData); err != nil {
		render.Status(r, http.StatusBadRequest)
		render.JSON(w, r, newError(err.Error()))
		log.Errorln("[updateYmlFromJson] 校验错误: %s", err)
		return
	}
	if err := ioutil.WriteFile(C.Path.Config(), ymlData, 0644); err != nil {
		render.Status(r, http.StatusInternalServerError)
		render.JSON(w, r, newError(err.Error()))
		log.Errorln("[updateYmlFromJson] 文件写入错误: %s", err)
		return
	}
	// fmt.Println("Info: JSON配置更新成功")
	log.Infoln("Info: JSON配置更新成功")
	render.JSON(w, r, map[string]string{"status": "success"})
}
