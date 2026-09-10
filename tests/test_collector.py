import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import collector


class TelemetryTests(unittest.TestCase):
    def test_disk_rates_use_elapsed_time_and_reject_resets(self):
        previous = {'sda': (1024, 2048)}
        sample = collector.disk_sample({'sda': (3072, 6144)}, previous, 2)
        self.assertEqual(sample['readRate'], 1024)
        self.assertEqual(sample['writeRate'], 2048)
        self.assertIsNone(collector.disk_sample(previous, {}, 2)['readRate'])
        self.assertIsNone(collector.disk_sample({'sda': (0, 0)}, previous, 2)['readRate'])
        self.assertIsNone(collector.disk_sample(previous, previous, 0)['readRate'])

    def test_disk_counters_skip_partitions_and_virtual_layers(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / 'block/sda/device').mkdir(parents=True)
            raw = '\n'.join(f'8 0 {name} 1 0 10 0 1 0 20 0 0 0 0' for name in ['sda', 'sda1', 'dm-0', 'loop0'])
            self.assertEqual(collector.disk_counters(raw, root), {'sda': (5120, 10240)})

    @patch('collector.shutil.disk_usage', side_effect=OSError)
    def test_unavailable_disk_capacity_still_reports_io(self, usage):
        result = collector.disk_sample({'sda': (10, 20)}, {'sda': (0, 0)}, 1)
        self.assertIsNone(result['percent'])
        self.assertEqual(result['readRate'], 10)

    def test_cpu_model_and_missing_info(self):
        self.assertEqual(collector.cpu_model('processor: 0\nmodel name : Intel Core i7-12700K'), 'Intel Core i7-12700K')
        self.assertEqual(collector.cpu_model('Hardware: ARM board'), 'ARM board')
        self.assertEqual(collector.cpu_model(''), '')

    @patch('collector.read', return_value='73BF, C1, AMD Radeon RX 6800 XT\n73BF, C3, Another model')
    def test_amd_model_matches_revision(self, read):
        collector.gpu_model.cache_clear()
        self.assertEqual(collector.gpu_model('0000:03:00.0', '0x1002', '0x73bf', '0xc1'), 'AMD Radeon RX 6800 XT')
        collector.gpu_model.cache_clear()

    @patch('collector.subprocess.run', side_effect=FileNotFoundError)
    def test_model_lookup_failure_keeps_generic_name(self, run):
        collector.gpu_model.cache_clear()
        self.assertEqual(collector.gpu_model('0000:01:00.0', '0x8086', '0xffff', '0x00'), 'Intel GPU')
        collector.gpu_model.cache_clear()

    def test_cpu_deltas_do_not_double_count_guest(self):
        old = collector.cpu_ticks('cpu 100 0 50 800 50 0 0 0 20 0\ncpu0 50 0 25 400 25 0 0 0')
        new = collector.cpu_ticks('cpu 120 0 60 860 60 0 0 0 30 0\ncpu0 60 0 30 430 30 0 0 0')
        self.assertEqual(collector.cpu_percent(new, old), {'cpu': 30.0, 'cpu0': 30.0})

    def test_first_sample_hotplug_and_counter_reset_are_unknown(self):
        ticks = {'cpu': (100, 70), 'cpu1': (10, 5)}
        self.assertEqual(collector.cpu_percent(ticks, {}), {'cpu': None, 'cpu1': None})
        self.assertIsNone(collector.cpu_percent(ticks, {'cpu': (200, 80)})['cpu'])

    def test_memory_uses_available_not_free(self):
        result = collector.memory('MemTotal: 1000 kB\nMemFree: 100 kB\nMemAvailable: 600 kB')
        self.assertEqual(result, {'percent': 40.0, 'used': 409600, 'total': 1024000})
        self.assertIsNone(collector.memory('')['percent'])

    def test_absent_hardware_stays_unknown(self):
        with tempfile.TemporaryDirectory() as d:
            c = collector.Collector(Path(d), Path(d), False)
            s = c.sample()
            self.assertIsNone(s['cpu'])
            self.assertIsNone(s['cpuTemperature'])
            self.assertEqual(s['gpu'], {})
            self.assertTrue(s['error'])

    def test_amd_sensor_units_and_hotspot(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            device = root / 'class/drm/card1/device'
            hw = device / 'hwmon/hwmon0'
            hw.mkdir(parents=True)
            for name, value in {'vendor': '0x1002', 'gpu_busy_percent': '17', 'mem_info_vram_total': '17179869184', 'mem_info_vram_used': '2147483648'}.items():
                (device / name).write_text(value)
            for name, value in {'temp1_label': 'edge', 'temp1_input': '46000', 'temp2_label': 'junction', 'temp2_input': '51000', 'power1_average': '43000000', 'fan1_input': '748'}.items():
                (hw / name).write_text(value)
            gpu = collector.gpu_sysfs(root)[0]
            self.assertEqual(gpu['percent'], 17)
            self.assertEqual(gpu['temperature'], 46)
            self.assertEqual(gpu['hotspot'], 51)
            self.assertEqual(gpu['power'], 43)
            self.assertEqual(gpu['fan'], 748)
            self.assertEqual(gpu['used'] / gpu['total'], .125)

    def test_sensor_labels_and_invalid_temperature(self):
        with tempfile.TemporaryDirectory() as d:
            hw = Path(d) / 'class/hwmon/hwmon0'
            hw.mkdir(parents=True)
            for name, value in {'name': 'k10temp', 'temp1_input': '37000', 'temp1_label': 'Tctl', 'temp2_input': '200000'}.items():
                (hw / name).write_text(value)
            self.assertEqual(collector.sensors(Path(d)), [{'driver': 'k10temp', 'label': 'Tctl', 'value': 37}])

    @patch('collector.shutil.which', return_value='/usr/bin/nvidia-smi')
    @patch('collector.subprocess.run')
    def test_nvidia_missing_fields(self, run, which):
        run.return_value.stdout = '0, NVIDIA Test, 23, 512, 8192, 50, [N/A]\n'
        gpu = collector.nvidia()[0]
        self.assertEqual(gpu['used'], 512 * 1048576)
        self.assertEqual(gpu['percent'], 23)
        self.assertIsNone(gpu['power'])

    @patch('collector.shutil.which', return_value='/usr/bin/nvidia-smi')
    @patch('collector.subprocess.run', side_effect=collector.subprocess.TimeoutExpired('nvidia-smi', 1.2))
    def test_nvidia_timeout_does_not_stop_collector(self, run, which):
        self.assertEqual(collector.nvidia(), [])


if __name__ == '__main__':
    unittest.main()
