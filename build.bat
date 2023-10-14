@echo off

odin build src/generate.odin -file -out:gen.exe
odin build src/parse.odin -file -out:parse.exe -debug
