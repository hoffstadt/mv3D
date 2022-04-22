#ifndef SEMPER_JSON_H
#define SEMPER_JSON_H

#ifndef MV_IMPORTER_MAX_NAME_LENGTH
#define MV_IMPORTER_MAX_NAME_LENGTH 256
#endif

#include <string>
#include <assert.h>

struct sJsonObject;   // json object or array
struct sJsonValue;    // primitive/string json value
struct sJsonMember;   // json member (name + primitive/string value)
typedef int sJsonType;

// borrowed from Dear ImGui
template<typename T>
struct mvVector
{
	int size     = 0u;
	int capacity = 0u;
	T*  data     = nullptr;
	inline mvVector() { size = capacity = 0; data = nullptr; }
	inline mvVector<T>& operator=(const mvVector<T>& src) { clear(); resize(src.size); memcpy(data, src.data, (size_t)size * sizeof(T)); return *this; }
	//inline ~mvVector() { if (data) free(data); }
	inline bool empty() const { return size == 0; }
	inline int  size_in_bytes() const   { return size * (int)sizeof(T); }
	inline T&   operator[](int i) { assert(i >= 0 && i < size); return data[i]; }
	inline void clear() { if (data) { size = capacity = 0; free(data); data = nullptr; } }
	inline T*   begin() { return data; }
    inline T*   end() { return data + size; }
	inline T&   back() { assert(size > 0); return data[size - 1]; }
	inline void swap(mvVector<T>& rhs) { int rhs_size = rhs.size; rhs.size = size; size = rhs_size; int rhs_cap = rhs.capacity; rhs.capacity = capacity; capacity = rhs_cap; T* rhs_data = rhs.data; rhs.data = data; data = rhs_data; }
	inline int  _grow_capacity(int sz) { int new_capacity = capacity ? (capacity + capacity / 2) : 8; return new_capacity > sz ? new_capacity : sz; }
	inline void resize(int new_size) { if (new_size > capacity) reserve(_grow_capacity(new_size)); size = new_size; }
	inline void reserve(int new_capacity) { if (new_capacity <= capacity) return; T* new_data = (T*)malloc((size_t)new_capacity * sizeof(T)); if (data) { memcpy(new_data, data, (size_t)size * sizeof(T)); free(data); } data = new_data; capacity = new_capacity; }
	inline void push_back(const T& v) { if (size == capacity) reserve(_grow_capacity(size*2)); memcpy(&data[size], &v, sizeof(v)); size++;}
	inline void pop_back() { assert(size > 0); size--; }
};

enum sJsonType_
{
	S_JSON_TYPE_NONE,
	S_JSON_TYPE_STRING,
	S_JSON_TYPE_ARRAY,
	S_JSON_TYPE_PRIMITIVE,
	S_JSON_TYPE_OBJECT
};

struct sJsonValue
{
	mvVector<char> value;
};

struct sJsonObject
{
	sJsonType              type;
	sJsonObject*           children;
	int                    childCount;
	
	char                   name[MV_IMPORTER_MAX_NAME_LENGTH];
	sJsonValue             value;
	void*                  _internal;

	sJsonObject& getMember(const char* member);
	bool         doesMemberExist(const char* member);

	sJsonObject& operator[](const char* member);
	inline sJsonObject& operator[](int i) { return children[i]; };

	inline operator int()         { return atoi(value.value.data);}
	inline operator unsigned()    { int v = atoi(value.value.data); return (unsigned)v;}
	inline operator float()       { return atof(value.value.data);}
	inline operator std::string() { return std::string(value.value.data);}

};

sJsonObject* ParseJSON(char* rawData, int size);

#endif