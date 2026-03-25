## ACL設定

## コード全文

~~~
{
	// Declare static groups of users. Use autogroups for all users or users with a specific role.
	"groups": {
		"group:myself": ["me@example.com"],
	},

	// Define the tags which can be applied to devices and by which users.
	"tagOwners": {
		"tag:phone":     ["group:myself"],
		"tag:clientpc":  ["group:myself"],
		"tag:nextcloud": ["group:myself"],
		"tag:freshrss":  ["group:myself"],
	},

	// Define access control lists for users, groups, autogroups, tags,
	// Tailscale IP addresses, and subnet ranges.
	"acls": [
		// Allow connecttion from my phones.
		// It allows ssh to servers.
		// It allows http(s) to connect freshrss api.
		{
			"action": "accept",
			"src":    ["tag:phone"],
			"dst": [
				"tag:nextcloud:22",
				"tag:freshrss:22,80,443",
			],
		},

		// Allow connection for my main client pc.
		// It allows http(s) to connect nextcloud desktop client and freshrss web ui.
		{
			"action": "accept",
			"src":    ["tag:clientpc"],
			"dst": [
				"tag:nextcloud:80,443",
				"tag:freshrss:80,443",
			],
		},
	],
}
~~~
