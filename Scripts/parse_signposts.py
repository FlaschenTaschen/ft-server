#!/usr/bin/env python3
"""
Parse signpost logs from FlaschenTaschen performance testing.

Extracts duration data for each operation by matching begin/end pairs
and generates statistics (min/max/avg/std dev).

Usage:
    python3 parse_signposts.py <log_file>
    python3 parse_signposts.py debug/performance/perf-baseline1-*.log
"""

import sys
import re
from datetime import datetime
from collections import defaultdict
import statistics
from pathlib import Path


def parse_timestamp(ts_str):
    """Parse timestamp like '2026-03-06 23:13:35.694782-0800' to float seconds."""
    # Remove timezone for parsing
    ts_clean = ts_str.rsplit('-', 1)[0]  # Remove '-0800'
    dt = datetime.fromisoformat(ts_clean)
    return dt.timestamp()


def extract_signpost_name(line, with_context=True):
    """Extract signpost name from log line.

    Args:
        line: Log line to parse
        with_context: If True, include context like layer ID in returned name

    Returns:
        Tuple of (base_name, full_name_with_context)
    """
    # Look for pattern like [co.sstools.FlaschenTaschen:Performance] operationName
    match = re.search(r'\[co\.sstools\.FlaschenTaschen:Performance\]\s+([a-zA-Z0-9_]+)', line)
    if match:
        base_name = match.group(1)

        # Extract additional context like layer ID if present
        full_name = base_name
        if with_context and 'layer=' in line:
            layer_match = re.search(r'layer=(\d+)', line)
            if layer_match:
                full_name = f"{base_name}:layer={layer_match.group(1)}"

        return base_name, full_name
    return None, None


def parse_log_file(filepath):
    """Parse a single signpost log file and return durations dict."""
    operations = defaultdict(list)  # operation_name -> list of durations (ms)
    stacks = defaultdict(list)  # thread_id -> stack of (name, timestamp, line_num)

    try:
        with open(filepath, 'r') as f:
            lines = f.readlines()
    except FileNotFoundError:
        print(f"Error: File not found: {filepath}", file=sys.stderr)
        return operations

    for line_num, line in enumerate(lines, 1):
        # Skip header or malformed lines
        if 'Timestamp' in line or not line.strip():
            continue

        # Extract timestamp
        timestamp_match = re.match(r'(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+-\d{4})', line)
        if not timestamp_match:
            continue

        timestamp_str = timestamp_match.group(1)
        timestamp = parse_timestamp(timestamp_str)

        # Extract thread ID for stack tracking
        thread_match = re.search(r'0x[0-9a-f]+', line)
        if not thread_match:
            continue
        thread_id = thread_match.group(0)

        # Determine if begin or end
        is_begin = 'begin' in line
        is_end = 'end' in line and 'begin' not in line

        # Extract signpost name (both base and full with context)
        base_name, full_name = extract_signpost_name(line)
        if not base_name:
            continue

        # Skip fpsMeasurement events (they're not begin/end pairs)
        if 'fpsMeasurement' in base_name:
            continue

        if is_begin:
            # Push to stack with full name (for reporting) but match by base_name
            stacks[thread_id].append((base_name, full_name, timestamp, line_num))
        elif is_end:
            # Pop from stack and calculate duration - match by base_name
            if stacks[thread_id] and stacks[thread_id][-1][0] == base_name:
                saved_base, full_name_from_begin, begin_ts, begin_line = stacks[thread_id].pop()
                duration_ms = (timestamp - begin_ts) * 1000  # Convert to milliseconds
                operations[full_name_from_begin].append(duration_ms)
            elif stacks[thread_id]:
                # Mismatched - log for debugging if needed
                # print(f"  Warning: Mismatched end {base_name} at line {line_num}, expected {stacks[thread_id][-1][0]}", file=sys.stderr)
                pass
            # else: mismatched begin/end, skip

    return operations


def format_stats(durations):
    """Format statistics for a list of durations."""
    if not durations:
        return None

    count = len(durations)
    min_d = min(durations)
    max_d = max(durations)
    avg_d = statistics.mean(durations)
    std_d = statistics.stdev(durations) if count > 1 else 0.0

    return {
        'count': count,
        'min': min_d,
        'max': max_d,
        'avg': avg_d,
        'std': std_d,
    }


def print_report(all_operations, filenames):
    """Print formatted performance report."""
    print("\n" + "="*80)
    print("SIGNPOST PERFORMANCE ANALYSIS")
    print("="*80)
    print(f"Files analyzed: {', '.join([Path(f).name for f in filenames])}\n")

    # Aggregate across files
    aggregated = defaultdict(list)
    for ops in all_operations:
        for name, durations in ops.items():
            aggregated[name].extend(durations)

    # Print per-operation stats
    print(f"{'Operation':<35} {'Count':>6} {'Min (ms)':>10} {'Max (ms)':>10} {'Avg (ms)':>10} {'Std Dev':>10}")
    print("-" * 82)

    for name in sorted(aggregated.keys()):
        durations = aggregated[name]
        stats = format_stats(durations)
        if stats:
            print(f"{name:<35} {stats['count']:>6} {stats['min']:>10.3f} "
                  f"{stats['max']:>10.3f} {stats['avg']:>10.3f} {stats['std']:>10.3f}")

    # Summary
    print("\n" + "-"*82)
    total_ops = sum(len(durations) for durations in aggregated.values())
    print(f"Total operations measured: {total_ops}\n")

    # Per-file breakdown
    print("\nPER-FILE BREAKDOWN:")
    print("-"*82)
    for filepath, ops in zip(filenames, all_operations):
        print(f"\n{Path(filepath).name}:")
        print(f"  {'Operation':<30} {'Count':>6} {'Min (ms)':>10} {'Avg (ms)':>10} {'Max (ms)':>10}")
        for name in sorted(ops.keys()):
            stats = format_stats(ops[name])
            if stats:
                print(f"  {name:<30} {stats['count']:>6} {stats['min']:>10.3f} "
                      f"{stats['avg']:>10.3f} {stats['max']:>10.3f}")


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 parse_signposts.py <log_file> [log_file2 ...]")
        print("       python3 parse_signposts.py debug/performance/perf-baseline*.log")
        sys.exit(1)

    filenames = sys.argv[1:]
    all_operations = []

    # Expand glob patterns and parse each file
    import glob
    expanded_files = []
    for pattern in filenames:
        expanded = glob.glob(pattern)
        if expanded:
            expanded_files.extend(expanded)
        else:
            expanded_files.append(pattern)

    for filepath in expanded_files:
        print(f"Parsing {Path(filepath).name}...", end=' ', file=sys.stderr)
        ops = parse_log_file(filepath)
        if ops:
            all_operations.append(ops)
            print(f"✓", file=sys.stderr)
        else:
            print(f"(no data)", file=sys.stderr)

    if all_operations:
        print_report(all_operations, expanded_files)
    else:
        print("Error: No valid signpost data found in logs", file=sys.stderr)
        sys.exit(1)


if __name__ == '__main__':
    main()
