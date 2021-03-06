#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

args <- commandArgs(trailingOnly = TRUE)

hashCode <- as.integer(args[1])
port <- as.integer(args[2])
libPath <- args[3]
version <- as.integer(args[4])
timeout <- as.integer(args[5])
isSparkSupported <- args[6]
authSecret <- NULL
if (length(args) >= 7) {
  authSecret <- args[7]
}

rm(args)

print(paste("Port ", toString(port)))
print(paste("LibPath ", libPath))

.libPaths(c(file.path(libPath), .libPaths()))
library(SparkR)

if (is.null(authSecret)) {
  SparkR:::connectBackend("localhost", port, timeout)
} else {
  SparkR:::connectBackend("localhost", port, timeout, authSecret)
}

# scStartTime is needed by R/pkg/R/sparkR.R
assign(".scStartTime", as.integer(Sys.time()), envir = SparkR:::.sparkREnv)

# getZeppelinR
.zeppelinR = SparkR:::callJStatic("org.apache.zeppelin.r.ZeppelinR", "getZeppelinR", hashCode)

if (isSparkSupported == "true") {
  # setup spark env
  assign(".sc", SparkR:::callJStatic("org.apache.zeppelin.spark.ZeppelinRContext", "getSparkContext"), envir = SparkR:::.sparkREnv)
  assign("sc", get(".sc", envir = SparkR:::.sparkREnv), envir=.GlobalEnv)
  if (version >= 20000) {
   assign(".sparkRsession", SparkR:::callJStatic("org.apache.zeppelin.spark.ZeppelinRContext", "getSparkSession"), envir = SparkR:::.sparkREnv)
   assign("spark", get(".sparkRsession", envir = SparkR:::.sparkREnv), envir = .GlobalEnv)
   assign(".sparkRjsc", SparkR:::callJStatic("org.apache.zeppelin.spark.ZeppelinRContext", "getJavaSparkContext"), envir = SparkR:::.sparkREnv)
  }
  assign(".sqlc", SparkR:::callJStatic("org.apache.zeppelin.spark.ZeppelinRContext", "getSqlContext"), envir = SparkR:::.sparkREnv)
  assign("sqlContext", get(".sqlc", envir = SparkR:::.sparkREnv), envir = .GlobalEnv)
  assign(".zeppelinContext", SparkR:::callJStatic("org.apache.zeppelin.spark.ZeppelinRContext", "getZeppelinContext"), envir = .GlobalEnv)
} else {
  assign(".zeppelinContext", SparkR:::callJStatic("org.apache.zeppelin.r.RInterpreter", "getRZeppelinContext"), envir = .GlobalEnv)
}

z.put <- function(name, object) {
  SparkR:::callJMethod(.zeppelinContext, "put", name, object)
}

z.get <- function(name) {
  SparkR:::callJMethod(.zeppelinContext, "get", name)
}

z.getAsDataFrame <- function(name) {
  stringValue <- z.get(name)
  read.table(text=stringValue, header=TRUE, sep="\t")
}

z.angular <- function(name, noteId=NULL, paragraphId=NULL) {
  SparkR:::callJMethod(.zeppelinContext, "angular", name, noteId, paragraphId)
}

z.angularBind <- function(name, value, noteId=NULL, paragraphId=NULL) {
  SparkR:::callJMethod(.zeppelinContext, "angularBind", name, value, noteId, paragraphId)
}

z.textbox <- function(name, value) {
  SparkR:::callJMethod(.zeppelinContext, "textbox", name, value)
}

z.noteTextbox <- function(name, value) {
  SparkR:::callJMethod(.zeppelinContext, "noteTextbox", name, value)
}

z.password <- function(name) {
  SparkR:::callJMethod(.zeppelinContext, "password", name)
}

z.notePassword <- function(name) {
  SparkR:::callJMethod(.zeppelinContext, "notePassword", name)
}

z.run <- function(paragraphId) {
  SparkR:::callJMethod(.zeppelinContext, "run", paragraphId)
}

z.runNote <- function(noteId) {
  SparkR:::callJMethod(.zeppelinContext, "runNote", noteId)
}

z.runAll <- function() {
  SparkR:::callJMethod(.zeppelinContext, "runAll")
}

z.angular <- function(name) {
  SparkR:::callJMethod(.zeppelinContext, "angular", name)
}

z.angularBind <- function(name, value) {
  SparkR:::callJMethod(.zeppelinContext, "angularBind", name, value)
}

z.angularUnbind <- function(name, value) {
  SparkR:::callJMethod(.zeppelinContext, "angularUnbind", name)
}

# notify script is initialized
SparkR:::callJMethod(.zeppelinR, "onScriptInitialized")

while (TRUE) {
  req <- SparkR:::callJMethod(.zeppelinR, "getRequest")
  type <-  SparkR:::callJMethod(req, "getType")
  stmt <- SparkR:::callJMethod(req, "getStmt")
  value <- SparkR:::callJMethod(req, "getValue")
  
  if (type == "eval") {
    tryCatch({
      ret <- eval(parse(text=stmt))
      SparkR:::callJMethod(.zeppelinR, "setResponse", "", FALSE)
    }, error = function(e) {
      SparkR:::callJMethod(.zeppelinR, "setResponse", toString(e), TRUE)
    })    
  } else if (type == "set") {
    tryCatch({
      ret <- assign(stmt, value)
      SparkR:::callJMethod(.zeppelinR, "setResponse", "", FALSE)
    }, error = function(e) {
      SparkR:::callJMethod(.zeppelinR, "setResponse", toString(e), TRUE)
    })
  } else if (type == "get") {
    tryCatch({      
      ret <- eval(parse(text=stmt))
      SparkR:::callJMethod(.zeppelinR, "setResponse", ret, FALSE)
    }, error = function(e) {
      SparkR:::callJMethod(.zeppelinR, "setResponse", toString(e), TRUE)
    })
  } else if (type == "getS") {
    tryCatch({
      ret <- eval(parse(text=stmt))
      SparkR:::callJMethod(.zeppelinR, "setResponse", toString(ret), FALSE)
    }, error = function(e) {
      SparkR:::callJMethod(.zeppelinR, "setResponse", toString(e), TRUE)
    })
  } else {
    # unsupported type
    SparkR:::callJMethod(.zeppelinR, "setResponse", paste("Unsupported type ", type), TRUE)
  }
}
