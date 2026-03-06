# Debugging the FT Server

## Collecting Logs

Use the `log` command-line tool to stream logs from the server. The server uses:
- **Subsystem:** `co.sstools.FlaschenTaschen`
- **Categories:** `UDPServer`, `PPMParser`, etc.

### View all FT server logs:
```bash
log stream --predicate 'subsystem == "co.sstools.FlaschenTaschen"'
```

### View only UDP server logs (new connections, errors, etc.):
```bash
log stream --predicate 'subsystem == "co.sstools.FlaschenTaschen" and category == "UDPServer"'
```

### View only PPM parser logs (image parsing issues):
```bash
log stream --predicate 'subsystem == "co.sstools.FlaschenTaschen" and category == "PPMParser"'
```

### Save logs to a file for analysis:
```bash
log collect --predicate 'subsystem == "co.sstools.FlaschenTaschen"' --output /tmp/ft-logs.logarchive
```

Then extract and view with:
```bash
log show /tmp/ft-logs.logarchive --predicate 'subsystem == "co.sstools.FlaschenTaschen"'
```

### Real-time debugging (shows new connections + errors):
```bash
log stream --predicate 'subsystem == "co.sstools.FlaschenTaschen"' --level debug
```

These commands will help debug connection issues, image parsing problems, and other server behavior.
