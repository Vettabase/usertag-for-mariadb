-- Get all usertags.
-- The list should be empty at this point.
-- usertag_get accepts 2 arguments: username and tag.
-- Both are actually LIKE patterns, so you can use the
-- '%' and '_' jolly characters.
CALL usertag_get('%', '%');
-- If you find it easier, you can also use
-- usertag_get_all() as a shortcut.
CALL usertag_get_all();


-- Add a tag for user 'emma':
CALL usertag_set('emma', 'team', 'sales');
-- usertag_set() can also set a new value for an existing tag:
CALL usertag_set('emma', 'team', 'marketing');
-- Unset (delete) a tag and all its children:
CALL usertag_unset('emma', 'team');

-- We recommend to organise tags in categories, with a dotted syntax.
-- A dot means that the name at its left hand is the parent tag,
-- and the name at its right is the child tag.
CALL usertag_set('eliza', 'team', 'ai');
CALL usertag_set('eliza', 'name.first', 'Elisa');
CALL usertag_set('eliza', 'name.last', 'Smith');
CALL usertag_set('eliza', 'contact.email', 'eliza@gmail.com');
CALL usertag_set('eliza', 'contact.phone', '+4412345');
CALL usertag_set('emma', 'contact.email', 'emma@gmail.com');
CALL usertag_set('emma', 'contact.phone', '+39123123123');
CALL usertag_set('emma', 'contact.im.skype', 'emma_emma');

-- As mentioned, usertag_get(user, tag) can be passed LIKE patterns.
-- So now you can see a specific tag, a category, or all tags for a user:
CALL usertag_get('eliza', 'contact.email');
CALL usertag_get('eliza', 'contact.%');
CALL usertag_get('eliza', '%');

-- Or you can see all contacts for all users:
CALL usertag_get('%', 'contact.%');

-- Note that, if your usernames also express a hierachy
-- of some type, you can also display tags for all users
-- in a category:
CALL usertag_get('fr.%', 'team');
CALL usertag_get('ch.%', 'contact.%');
CALL usertag_get('es.%', '%');

-- Find the user with a given email:
CALL user_find_by_tag('contact.email', 'emma@gmail.com');
-- "contact.email" is a child of "contact", so we can also search it this way:
CALL user_find_by_tag('contact.email', 'emma@gmail.com');
-- Find the user(s) who has a certain email in any tag:
CALL user_find_by_tag(NULL, 'emma@gmail.com');
-- Find the user(s) who has a certain tag, regardless its value:
CALL user_find_by_tag('contact.email', NULL);

-- How to handle user renaming:
RENAME USER emma TO anita;
CALL usertag_rename_user('emma', 'anita');

-- Now and then, you should probably do some seasonal cleaning.
-- Some users might have been dropped, and their tahs are probably orphaned.
-- To find dropped users who still have tags, use this view:
SELECT * FROM orphan_usertag;

-- To remove all tags from an active or dropped user:
CALL usertag_unset_for_user('eliza');

-- Set definition for a tag
CALL usertag_definition_set('contact.email', 'User email');
-- Get definitions
-- Should return nothing
CALL usertag_definition_get('contact');
-- Should return "contact.email" definition
CALL usertag_definition_get('contact.email');
CALL usertag_definition_set('contact', 'User contacts for normal communications');
CALL usertag_definition_set('contact.emergency', 'User emergency contacts');
-- Should return "contact" definition
CALL usertag_definition_get('contact');
-- Should return "contact.emergency" definition
CALL usertag_definition_get('contact.emergency');
-- Should return "contact.emergency" definition
CALL usertag_definition_get('contact.emergency.phone');
CALL usertag_definition_set('contact.emergency.phone', 'User phone to use in case of emergency');
-- Should return "contact" definition
CALL usertag_definition_get('contact');
-- Should return "contact.emergency" definition
CALL usertag_definition_get('contact.emergency');
-- Should return "contact.emergency.phone" definition
CALL usertag_definition_get('contact.emergency.phone');
-- Should return nothing
CALL usertag_definition_get('contacts');

-- Unset a definition and verify that it's been unset
CALL usertag_definition_unset('contact.emergency.phone');
CALL usertag_definition_get('contact.emergency.phone');

-- List all tags whose definition contains "contact"
CALL usertag_find_by_definition('%contact%');
-- List all tags and definitions
CALL usertag_find_by_definition('%');
-- List all tags and definitions
CALL usertag_definition_get_all();

-- See the history of value changes for user 'john', tag 'contact.email'
CALL usertag_hist_get('john', 'contact.email');
-- See the history of definitions for the contact.email tag
CALL usertag_hist_definition_get('contact.email')
