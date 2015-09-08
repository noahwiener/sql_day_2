require 'singleton'
require 'sqlite3'

class QuestionsDatabase < SQLite3::Database

  include Singleton

  def initialize
    super('questions.db')
    self.results_as_hash = true
    self.type_translation = true
  end

end

class SuperTable

  def self.find_by_id(id)
    data = QuestionsDatabase.instance.execute(<<-SQL, id: id).first
      SELECT
        *
      FROM
        #{self::TABLE_NAME}
      WHERE
        id = :id
      SQL
    self.new(data)
  end

  attr_reader :id
end

class User < SuperTable
  TABLE_NAME = 'users'

  def self.find_by_name(fname, lname)
    data = QuestionsDatabase.instance.execute(<<-SQL, fname: fname, lname: lname)
      SELECT
        *
      FROM
        #{TABLE_NAME}
      WHERE
        fname = :fname
        lname = :lname
      SQL
    users = []
    data.each do |datum|
      users << self.new(datum)
    end
    users
  end

  attr_accessor :fname, :lname

  def initialize(options = {})
    @id = options['id']
    @fname = options['fname']
    @lname = options['lname']
  end

  def authored_questions
    Question.find_by_author_id(id)
  end

  def authored_replies
    Reply.find_by_user_id(id)
  end
end

class Question < SuperTable
  TABLE_NAME = 'questions'

  def self.find_by_author_id(user_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, user_id: user_id)
      SELECT
        *
      FROM
        #{TABLE_NAME}
      WHERE
        user_id = :user_id
      SQL
    questions = []
    data.each do |datum|
      questions << self.new(datum)
    end
    questions
  end

  attr_accessor :title, :body, :user_id

  def initialize(options = {})
    @id = options['id']
    @title = options['title']
    @body = options['body']
    @user_id = options['user_id']
  end

  def author
    User.find_by_id(user_id)
  end

  def replies
    Reply.find_by_question_id(id)
  end
end

class QuestionFollow < SuperTable
  TABLE_NAME = 'questions'

  attr_accessor :user_id, :question_id

  def initialize(options = {})
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
  end
end

class Reply < SuperTable
  TABLE_NAME = 'replies'

  def self.find_by_user_id(user_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, user_id: user_id)
      SELECT
        *
      FROM
        #{TABLE_NAME}
      WHERE
        user_id = :user_id
      SQL
    replies = []
    data.each do |datum|
      replies << self.new(datum)
    end
    replies
  end

  def self.find_by_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, question_id: question_id)
      SELECT
        *
      FROM
        #{TABLE_NAME}
      WHERE
        question_id = :question_id
      SQL
    replies = []
    data.each do |datum|
      replies << self.new(datum)
    end
    replies
  end

  attr_accessor :user_id, :question_id, :parent_id, :body

  def initialize(options = {})
    @id = options['id']
    @user_id = options['user_id']
    @question_id = options['question_id']
    @parent_id = options['parent_id']
    @body = options['body']
  end

  def author
    User.find_by_id(user_id)
  end

  def question
    Question.find_by_id(question_id)
  end

  def parent_reply
    if parent_id
      Reply.find_by_id(parent_id)
    else
      puts "This is the first reply"
    end
  end

  def child_replies
    q = Question.find_by_id(question_id)
    child_replies = []
    q.replies.each do |reply|
      child_replies << reply if reply.parent_id == id
    end
    child_replies
  end
end

class QuestionLike < SuperTable
  TABLE_NAME = 'question_likes'

  attr_accessor :question_id, :user_id

  def initialize(options = {})
    @id = options['id']
    @question_id = options['question_id']
    @user_id = options['user_id']
  end
end



# NOTES
# QuestionsDatabase.instance.execute(sql_fragment, var1, var2, var3: var3)
# ? => var1
# ? => var2
# :var3 => var3

# data = QuestionsDatabase.instance.execute(<<-SQL)
# [6] pry(main)* SELECT
# [6] pry(main)* *
# [6] pry(main)* FROM
# [6] pry(main)* users
# [6] pry(main)* WHERE
# [6] pry(main)* id = 1
# [6] pry(main)* SQL
# => [{"id"=>1, "fname"=>"Noah", "lname"=>"Wiener"}]
