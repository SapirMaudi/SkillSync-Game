package objects

import "sync"

type SharedCollection[T any] struct {
	objectMap map[uint64]T
	nextId    uint64
	mapMux    sync.Mutex
}

func NewSharedCollection[T any](capacity ...int) *SharedCollection[T] {
	var newObjMap map[uint64]T

	if len(capacity) > 0 {
		newObjMap = make(map[uint64]T, capacity[0])
	} else {
		newObjMap = make(map[uint64]T)
	}

	return &SharedCollection[T]{
		objectMap: newObjMap,
		nextId:    1,
	}
}

func (s *SharedCollection[T]) Add(obj T, id ...uint64) uint64 {
	s.mapMux.Lock()
	defer s.mapMux.Unlock()

	newId := s.nextId
	if len(id) > 0 {
		newId = id[0]
	}

	s.objectMap[newId] = obj
	s.nextId++
	return newId
}

func (s *SharedCollection[T]) Remove(id uint64) {
	s.mapMux.Lock()
	defer s.mapMux.Unlock()

	delete(s.objectMap, id)
}

func (s *SharedCollection[T]) ForEach(callback func(uint64, T)) {
	s.mapMux.Lock()

	mapCopy := make(map[uint64]T, len(s.objectMap))
	for id, obj := range s.objectMap {
		mapCopy[id] = obj
	}
	s.mapMux.Unlock()

	for id, obj := range mapCopy {
		callback(id, obj)
	}
}

func (s *SharedCollection[T]) Get(id uint64) (T, bool) {
	s.mapMux.Lock()
	defer s.mapMux.Unlock()

	obj, exists := s.objectMap[id]
	return obj, exists
}

func (s *SharedCollection[T]) Len() int {
	s.mapMux.Lock()
	defer s.mapMux.Unlock()

	return len(s.objectMap)
}
