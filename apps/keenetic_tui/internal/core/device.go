package core

import (
	"net"
	"sort"
	"strconv"
	"strings"
)

type LocalDeviceInfoService struct{}

func (LocalDeviceInfoService) GetLocalIPv4CIDRs() ([]string, error) {
	interfaces, err := net.Interfaces()
	if err != nil {
		return nil, err
	}
	set := map[string]struct{}{}
	for _, iface := range interfaces {
		if iface.Flags&net.FlagLoopback != 0 || iface.Flags&net.FlagUp == 0 {
			continue
		}
		addrs, err := iface.Addrs()
		if err != nil {
			continue
		}
		for _, addr := range addrs {
			ip, network, ok := parseIPv4Network(addr)
			if !ok || ip.IsLoopback() || ip.IsLinkLocalUnicast() {
				continue
			}
			prefix, _ := network.Mask.Size()
			set[ip.String()+"/"+itoa(prefix)] = struct{}{}
		}
	}
	return sortedSet(set), nil
}

func (LocalDeviceInfoService) GetLocalMACAddresses() ([]string, error) {
	interfaces, err := net.Interfaces()
	if err != nil {
		return nil, err
	}
	set := map[string]struct{}{}
	for _, iface := range interfaces {
		if iface.Flags&net.FlagLoopback != 0 || iface.Flags&net.FlagUp == 0 {
			continue
		}
		mac := normalizeMAC(iface.HardwareAddr.String())
		if mac == "" {
			continue
		}
		set[mac] = struct{}{}
	}
	return sortedSet(set), nil
}

func parseIPv4Network(addr net.Addr) (net.IP, *net.IPNet, bool) {
	switch value := addr.(type) {
	case *net.IPNet:
		ip := value.IP.To4()
		if ip == nil {
			return nil, nil, false
		}
		return ip, &net.IPNet{IP: ip, Mask: value.Mask}, true
	case *net.IPAddr:
		ip := value.IP.To4()
		if ip == nil {
			return nil, nil, false
		}
		return ip, &net.IPNet{IP: ip, Mask: net.CIDRMask(24, 32)}, true
	default:
		return nil, nil, false
	}
}

func sortedSet(set map[string]struct{}) []string {
	values := make([]string, 0, len(set))
	for value := range set {
		values = append(values, value)
	}
	sort.Strings(values)
	return values
}

func normalizeMAC(value string) string {
	value = strings.TrimSpace(strings.ToLower(value))
	if value == "" {
		return ""
	}
	value = strings.ReplaceAll(value, "-", ":")
	return value
}

func itoa(value int) string {
	return strconv.Itoa(value)
}
