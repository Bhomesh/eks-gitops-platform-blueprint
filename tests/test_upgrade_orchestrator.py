import unittest
from tools.upgrade_orchestrator import UpgradeOrchestrator

class TestUpgradeOrchestrator(unittest.TestCase):
    def setUp(self):
        self.orchestrator = UpgradeOrchestrator(
            cluster_name="test-eks-cluster",
            target_version="1.32",
            dry_run=True
        )

    def test_dry_run_upgrade_success(self):
        result = self.orchestrator.execute()
        self.assertTrue(result)

    def test_preflight_pdb_failure_halts_upgrade(self):
        result = self.orchestrator.run_preflight_checks(mock_healthy_pdbs=False)
        self.assertFalse(result)

    def test_preflight_node_unready_halts_upgrade(self):
        result = self.orchestrator.run_preflight_checks(mock_healthy_nodes=False)
        self.assertFalse(result)

if __name__ == "__main__":
    unittest.main()
