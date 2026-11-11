// Inventory exported Go declarations without executing upstream code.
package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"go/ast"
	"go/parser"
	"go/printer"
	"go/token"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

type Symbol struct {
	Kind      string `json:"kind"`
	Name      string `json:"name"`
	Signature string `json:"signature,omitempty"`
	Line      int    `json:"line"`
}
type File struct {
	Path    string   `json:"path"`
	Package string   `json:"package"`
	SHA256  string   `json:"sha256"`
	Schema  string   `json:"schema,omitempty"`
	Release string   `json:"release,omitempty"`
	Symbols []Symbol `json:"symbols"`
}

func main() {
	if len(os.Args) != 2 {
		panic("usage: go run inventory.go /path/to/gofish@v0.27.0")
	}
	root := os.Args[1]
	fset := token.NewFileSet()
	render := func(n any) string {
		var b bytes.Buffer
		if err := printer.Fprint(&b, fset, n); err != nil {
			panic(err)
		}
		return strings.Join(strings.Fields(b.String()), " ")
	}
	var out []File
	err := filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil {
			return err
		}
		rel, err := filepath.Rel(root, path)
		if err != nil {
			return err
		}
		if d.IsDir() {
			if rel != "." && (strings.HasPrefix(d.Name(), ".") || rel == "examples" || rel == "images") {
				return filepath.SkipDir
			}
			return nil
		}
		if !strings.HasSuffix(rel, ".go") || strings.HasSuffix(rel, "_test.go") {
			return nil
		}
		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		node, err := parser.ParseFile(fset, path, data, parser.ParseComments)
		if err != nil {
			return err
		}
		if node.Name.Name == "main" {
			return nil
		}
		sum := sha256.Sum256(data)
		file := File{Path: filepath.ToSlash(rel), Package: filepath.ToSlash(filepath.Dir(rel)), SHA256: hex.EncodeToString(sum[:]), Symbols: []Symbol{}}
		schemaRE := regexp.MustCompile(`(?m)^// (https?://\S+\.json)\s*$`)
		if m := schemaRE.FindSubmatch(data); len(m) > 1 {
			file.Schema = string(m[1])
		}
		releaseRE := regexp.MustCompile(`(?m)^// ([0-9]{4}\.[0-9]+) -`)
		if m := releaseRE.FindSubmatch(data); len(m) > 1 {
			file.Release = string(m[1])
		}
		add := func(kind, name, signature string, pos token.Pos) {
			file.Symbols = append(file.Symbols, Symbol{kind, name, signature, fset.Position(pos).Line})
		}
		var fields func(string, *ast.FieldList, string)
		fields = func(owner string, list *ast.FieldList, kind string) {
			if list == nil {
				return
			}
			for _, f := range list.List {
				if len(f.Names) == 0 {
					add("embed", owner+"."+render(f.Type), render(f.Type), f.Pos())
					continue
				}
				for _, name := range f.Names {
					if !name.IsExported() {
						continue
					}
					sig := render(f.Type)
					if f.Tag != nil {
						sig += " " + f.Tag.Value
					}
					add(kind, owner+"."+name.Name, sig, name.Pos())
					if nested, ok := f.Type.(*ast.StructType); ok {
						fields(owner+"."+name.Name, nested.Fields, kind)
					}
				}
			}
		}
		for _, decl := range node.Decls {
			switch decl := decl.(type) {
			case *ast.FuncDecl:
				if !decl.Name.IsExported() {
					continue
				}
				kind, name := "function", decl.Name.Name
				if decl.Recv != nil {
					kind = "method"
					recv := render(decl.Recv.List[0].Type)
					name = recv + "." + name
				}
				add(kind, name, render(decl.Type), decl.Pos())
			case *ast.GenDecl:
				for _, spec := range decl.Specs {
					switch spec := spec.(type) {
					case *ast.TypeSpec:
						if !spec.Name.IsExported() {
							continue
						}
						sig := render(spec.Type)
						switch t := spec.Type.(type) {
						case *ast.StructType:
							sig = "struct"
							fields(spec.Name.Name, t.Fields, "field")
						case *ast.InterfaceType:
							sig = "interface"
							fields(spec.Name.Name, t.Methods, "interface_method")
						}
						if spec.TypeParams != nil {
							var params []string
							for _, p := range spec.TypeParams.List {
								var names []string
								for _, n := range p.Names {
									names = append(names, n.Name)
								}
								params = append(params, strings.Join(names, ",")+" "+render(p.Type))
							}
							sig = "[" + strings.Join(params, ", ") + "] " + sig
						}
						add("type", spec.Name.Name, sig, spec.Pos())
					case *ast.ValueSpec:
						for i, name := range spec.Names {
							if !name.IsExported() {
								continue
							}
							sig := ""
							if spec.Type != nil {
								sig = render(spec.Type)
							}
							if i < len(spec.Values) {
								sig += " = " + render(spec.Values[i])
							}
							add(decl.Tok.String(), name.Name, strings.TrimSpace(sig), name.Pos())
						}
					}
				}
			}
		}
		sort.Slice(file.Symbols, func(i, j int) bool {
			if file.Symbols[i].Name == file.Symbols[j].Name {
				return file.Symbols[i].Kind < file.Symbols[j].Kind
			}
			return file.Symbols[i].Name < file.Symbols[j].Name
		})
		out = append(out, file)
		return nil
	})
	if err != nil {
		panic(err)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Path < out[j].Path })
	enc := json.NewEncoder(os.Stdout)
	enc.SetEscapeHTML(false)
	if err := enc.Encode(out); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
