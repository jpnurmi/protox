#!/usr/bin/python3
# This Python file uses the following encoding: utf-8

import sys

if (len(sys.argv) < 2):
    print('Usage: combiner.py <main qml file> <output>')
    exit(1)

output_file = sys.argv[2]

handle = open(sys.argv[1], "r")
data = handle.readlines()
operator = "//include:"
operator_remove = "//[remove]"
output = []
for line in data:
    if operator in line:
        split = line.split(" ")
        incf = split[len(split)-1].replace('\n', '')
        _spaces = 0
        for symbol in line:
            if symbol == ' ':
                _spaces += 1
        spaces = ' ' * (_spaces - 1)
        print('Found include file: ' + incf)
        include = open(incf, "r")
        proceed = []
        for _line in include:
            if _line[:12] == "/*[remove]*/":
                continue
            if _line[:6] != "import":
                proceed.append(spaces + _line)
        include.close()
        output.append(spaces + "// included from " + incf + "\n")
        for __line in proceed:
            output.append(__line)
        output.append(spaces + "// end of file " + incf + "\n")
    else:
        output.append(line)
handle.close()
print('Generating ' + output_file)
handle = open(output_file, "w")

handle.write('// This file was generated by qmlcombiner.py\n')
handle.write('// Do not edit by hand!\n')
for line in output:
    handle.write(line)
handle.close()
