TARGET = paq9a
CXX ?= g++
CXXFLAGS ?= -Wall -O3
LDFLAGS ?= -s
AR = ar
RM ?= rm -f
SRCS = src/$(TARGET).cpp
OBJS = $(SRCS:%.cpp=%.o)
LDLIBS =

ifeq ($(STATIC), Y)
	LDFLAGS += -static
endif

all: $(TARGET)

$(TARGET): $(OBJS)
	$(CXX) $(CXXFLAGS) $^ $(LDFLAGS) $(LDLIBS) -o $@

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	$(RM) $(TARGET) $(OBJS)
