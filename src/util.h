/*
EM: Electronic Monitor - Control Box Software
Copyright (C) 2012 Ecotrust Canada
Knowledge Systems and Planning

This file is part of EM.

EM is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

EM is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with EM. If not, see <http://www.gnu.org/licenses/>.

You may contact Ecotrust Canada via our website http://ecotrust.ca
*/

/**
 * Converts all the characters in a string into upper case ones.
 * @param s The string to be converted.
 */
void toUpperCase(char* s);

/**
 * Converts a hex number in a string into a decimal one.
 * @param hexStr The string contains the hex number.
 * @param result The string to store the result decimal number.
 */
void hexStrToIntStr(char* hexStr, char* result);

/**
 * Convers a hex number in a string into a decimal integer.
 * @param ptr The string contains the hex number.
 * @return The decimal integer.
 */
unsigned int htoi (const char *ptr);

/**
 * Returns microseconds since the epoch
 * @return microseconds double
 */
double now();