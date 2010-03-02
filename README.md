fat_cache
=========

Data migration got you down? RAM to spare? Let `fat_cache` do the work for you.
`fat_cache` wastes resources for the sake of speed, intentionally!

Use Case
========

Say you are importing bank accounts associated with your users from an old
system, maybe 10,000 of them.

Naive Implementation
--------------------

You might write code that looks something like this:

    old_accounts = legacy_db.select_all("select * from old_accounts")

    old_accounts.each do |account_data|
      user = User.find_by_user_number(account_data['user_number'], :include => :accounts)
      next if user.accounts.find { |account| account.number == account_data['account_number'] }
      # Save imported account
      acct = Account.new(account_data)
      acct.save!
    end

But this is slow, two queries for each of your 10,000 accounts.

Refactor One: Fat Query
-----------------------

You can attack the speed problem by loading all your users into memory first.
You pay for a fat query up front, but you get a speed boost afterwards.

    old_accounts = legacy_db.select_all("select * from old_accounts")

    all_users = Users.all(:include => :accounts)

    old_accounts.each do |account_data|
      user = all_users.find { |user| user.user_number == account_data['user_number'] }
      # ... (same as above) ...
    end

But now instead of spending all your time in the network stack doing queries,
you're spinning the CPU doing a linear search through the `all_users` array.

Refactor Two: Indexed Hash
--------------------------

A similar "pay up front, gain later" strategy can be used on the in-memory data
structure by indexing it on the key that we will be searching on. 


    old_accounts = legacy_db.select_all("select * from old_accounts")
    all_users = Users.all(:include => :accounts)

    all_users_indexed_by_user_number = all_users.inject({}) do |hash, user|
                                        hash[user.user_number] = user
                                        hash
                                      end

    old_accounts.each do |account_data|
      user = all_user_by_user_number[account_data['user_number']]
      # ... (same as above) ...
    end

Now finding a user for an account is constant time lookup in the hash.

FatCache makes this strategy simpler
------------------------------------

FatCache is a simple abstraction and encapsulation of the strategies used in
each refactor.  Here is how the code looks:

    FatCache.store(:users) { Users.all(:include => :accounts) }
    FatCache.index(:users, :user_number)

    old_accounts.each do |account_data|
      user = FatCache.lookup :users, :by => :user_number, :using => account_data['user_number']
      # ... (same as above) ...
    end

And in fact, the call to `index` is optional, since `lookup` will create the
index the first time you call it if one doesn't exist, and you're still only
paying O(N) once. 
