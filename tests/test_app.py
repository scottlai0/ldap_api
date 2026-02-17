"""
Unit tests for the Flask LDAP application
Run with: python -m unittest test_app.py
"""
import unittest
import json
from app import app, sanitize_username


class TestUsernameSanitization(unittest.TestCase):
    """Test username validation and sanitization"""
    
    def test_valid_username(self):
        """Test that valid usernames are accepted"""
        self.assertEqual(sanitize_username('slaib'), 'slaib')
        self.assertEqual(sanitize_username('john.doe'), 'john.doe')
        self.assertEqual(sanitize_username('user-name'), 'user-name')
        self.assertEqual(sanitize_username('user_123'), 'user_123')
    
    def test_invalid_characters(self):
        """Test that usernames with invalid characters are rejected"""
        self.assertIsNone(sanitize_username('user@domain'))
        self.assertIsNone(sanitize_username('user;drop'))
        self.assertIsNone(sanitize_username('user(test)'))
        self.assertIsNone(sanitize_username('user/path'))
        self.assertIsNone(sanitize_username('user\\path'))
    
    def test_username_length(self):
        """Test username length validation"""
        # Valid length
        self.assertEqual(sanitize_username('a' * 64), 'a' * 64)
        # Too long
        self.assertIsNone(sanitize_username('a' * 65))
    
    def test_empty_username(self):
        """Test that empty usernames are rejected"""
        self.assertIsNone(sanitize_username(''))
        self.assertIsNone(sanitize_username(None))
    
    def test_whitespace_handling(self):
        """Test that whitespace is stripped"""
        self.assertEqual(sanitize_username('  user  '), 'user')


class TestAPIEndpoints(unittest.TestCase):
    """Test Flask API endpoints"""
    
    def setUp(self):
        """Set up test client"""
        self.app = app.test_client()
        self.app.testing = True
    
    def test_health_check_endpoint(self):
        """Test /health endpoint"""
        response = self.app.get('/health')
        self.assertIn(response.status_code, [200, 503])
        
        data = json.loads(response.data)
        self.assertIn('status', data)
        self.assertIn('ldap_server', data)
        self.assertIn('ldap_connected', data)
        
        if response.status_code == 200:
            self.assertEqual(data['status'], 'healthy')
            self.assertTrue(data['ldap_connected'])
        else:
            self.assertEqual(data['status'], 'unhealthy')
            self.assertFalse(data['ldap_connected'])
    
    def test_current_user_endpoint(self):
        """Test /api/user endpoint (current user)"""
        response = self.app.get('/api/user')
        self.assertEqual(response.status_code, 200)
        
        data = json.loads(response.data)
        self.assertIn('user', data)
        self.assertIn('authenticated', data)
        self.assertIn('auth_source', data)
        
        # Should have username
        self.assertIsNotNone(data['user']['username'])
        self.assertTrue(data['authenticated'])
    
    def test_valid_user_lookup(self):
        """Test /api/user/<username> with valid user"""
        response = self.app.get('/api/user/slaib')
        
        # Should be either 200 (found) or 404 (not found)
        self.assertIn(response.status_code, [200, 404])
        
        data = json.loads(response.data)
        self.assertIn('success', data)
        self.assertIn('username', data)
        
        if response.status_code == 200:
            self.assertTrue(data['success'])
            self.assertIn('data', data)
            self.assertIsInstance(data['data'], dict)
    
    def test_invalid_username_format(self):
        """Test /api/user/<username> with invalid username"""
        response = self.app.get('/api/user/user@test')
        self.assertEqual(response.status_code, 400)
        
        data = json.loads(response.data)
        self.assertFalse(data['success'])
        self.assertEqual(data['error'], 'Invalid username format')
    
    def test_nonexistent_user(self):
        """Test /api/user/<username> with non-existent user"""
        response = self.app.get('/api/user/nonexistentuser12345')
        
        # Should be either 404 (not found) or 400 (invalid format)
        self.assertIn(response.status_code, [400, 404])
        
        data = json.loads(response.data)
        self.assertFalse(data['success'])
        self.assertIn('error', data)
    
    def test_root_endpoint(self):
        """Test / endpoint"""
        response = self.app.get('/')
        self.assertEqual(response.status_code, 200)
        
        data = json.loads(response.data)
        self.assertIn('username', data)
        self.assertIn('domain', data)
        self.assertIn('authenticated', data)


class TestErrorHandling(unittest.TestCase):
    """Test error handling and HTTP status codes"""
    
    def setUp(self):
        """Set up test client"""
        self.app = app.test_client()
        self.app.testing = True
    
    def test_invalid_endpoint(self):
        """Test that invalid endpoints return 404"""
        response = self.app.get('/invalid/endpoint')
        self.assertEqual(response.status_code, 404)
    
    def test_sql_injection_attempt(self):
        """Test that SQL injection attempts are blocked"""
        response = self.app.get('/api/user/user;DROP TABLE users--')
        self.assertEqual(response.status_code, 400)
        
        data = json.loads(response.data)
        self.assertFalse(data['success'])
    
    def test_ldap_injection_attempt(self):
        """Test that LDAP injection attempts are blocked"""
        response = self.app.get('/api/user/user)(uid=*')
        self.assertEqual(response.status_code, 400)
        
        data = json.loads(response.data)
        self.assertFalse(data['success'])


class TestResponseFormat(unittest.TestCase):
    """Test API response formats"""
    
    def setUp(self):
        """Set up test client"""
        self.app = app.test_client()
        self.app.testing = True
    
    def test_json_content_type(self):
        """Test that all endpoints return JSON"""
        endpoints = ['/', '/api/user', '/health']
        
        for endpoint in endpoints:
            response = self.app.get(endpoint)
            self.assertIn('application/json', response.content_type)
    
    def test_user_endpoint_structure(self):
        """Test /api/user response structure"""
        response = self.app.get('/api/user')
        data = json.loads(response.data)
        
        # Required fields
        self.assertIn('user', data)
        self.assertIn('authenticated', data)
        
        # User object structure
        self.assertIn('username', data['user'])
        self.assertIn('domain', data['user'])
        self.assertIn('full_name', data['user'])


def run_tests():
    """Run all tests and print results"""
    # Create test suite
    loader = unittest.TestLoader()
    suite = unittest.TestSuite()
    
    # Add all test classes
    suite.addTests(loader.loadTestsFromTestCase(TestUsernameSanitization))
    suite.addTests(loader.loadTestsFromTestCase(TestAPIEndpoints))
    suite.addTests(loader.loadTestsFromTestCase(TestErrorHandling))
    suite.addTests(loader.loadTestsFromTestCase(TestResponseFormat))
    
    # Run tests with verbose output
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    
    # Print summary
    print("\n" + "=" * 70)
    print("TEST SUMMARY")
    print("=" * 70)
    print(f"Tests run: {result.testsRun}")
    print(f"Successes: {result.testsRun - len(result.failures) - len(result.errors)}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print("=" * 70)
    
    return result.wasSuccessful()


if __name__ == '__main__':
    # Run tests
    success = run_tests()
    
    # Exit with appropriate code
    exit(0 if success else 1)
