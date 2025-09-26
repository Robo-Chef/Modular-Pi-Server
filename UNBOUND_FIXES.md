# Unbound Configuration Fixes

This document explains the fixes applied to resolve Unbound health check issues
and ensure reliable deployment.

## Issues Fixed

### 1. **Wrong Port Configuration**

- **Problem**: Original config used port `5053` instead of `53`
- **Fix**: Updated `docker/unbound/config/unbound.conf` to use port `53`
- **Impact**: Matches Pi-hole's DNS configuration expectations

### 2. **Health Check SSL Certificate Error**

- **Problem**: Health check used `unbound-control status` which requires SSL
  certificates
- **Error**:
  `Error in SSL_CTX use_certificate_chain_file crypto error:80000002:system library::No such file or directory`
- **Fix**: Replaced with network connectivity test:
  `timeout 5 sh -c 'echo > /dev/tcp/127.0.0.1/53'`
- **Impact**: Health check works without requiring SSL certificate setup

### 3. **Volume Mount Configuration**

- **Problem**: Original mount was `./unbound/config:/etc/unbound/custom` but
  container didn't auto-include custom configs
- **Fix**: Changed to
  `./unbound/config/unbound.conf:/etc/unbound/unbound.conf:ro` (direct file
  mount)
- **Impact**: Container uses our configuration instead of built-in defaults

### 4. **Complex Configuration**

- **Problem**: Original config had many advanced options that could cause
  startup issues
- **Fix**: Simplified to minimal working configuration with essential security
  settings
- **Impact**: More reliable startup, easier troubleshooting

## Files Modified

1. **`docker/unbound/config/unbound.conf`**

   - Changed port from 5053 to 53
   - Simplified configuration
   - Disabled control interface
   - Added clear comments about health check approach

2. **`docker/docker-compose.core.yml`**

   - Fixed volume mount path
   - Updated health check command
   - Fixed commented port mappings (5053 → 5353 for debugging)

3. **`docs/troubleshooting.md`**
   - Added section about Unbound health check issues
   - Explained that "unhealthy" status may not indicate functional problems
   - Added DNS resolution test commands

## Testing

The fixes ensure that:

- ✅ Unbound starts reliably without configuration errors
- ✅ Health check passes using network connectivity test
- ✅ DNS resolution works correctly (Pi-hole → Unbound → Internet)
- ✅ No SSL certificate requirements for basic operation
- ✅ Container shows as "healthy" in Docker status

## For Future Deployments

These changes make the deployment more robust by:

- Using a minimal, tested configuration
- Avoiding SSL certificate complexity
- Providing clear troubleshooting guidance
- Ensuring health checks work out-of-the-box

Users should no longer encounter the "unhealthy" Unbound container issue that
required manual intervention.
