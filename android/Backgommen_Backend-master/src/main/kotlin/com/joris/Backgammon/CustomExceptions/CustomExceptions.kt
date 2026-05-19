package com.joris.Backgammon.CustomExceptions

class UserNotFoundException(message : String) : Exception(message)

class UserAlreadyExistException(message: String) : Exception(message)