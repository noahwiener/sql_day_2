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
        fname = :fname AND lname = :lname
      SQL
    data.map { |datum| self.new(datum) }
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

  def followed_questions
    QuestionFollow.followed_questions_for_user_id(id)
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
    # questions = []
    data.map { |datum| self.new(datum) }
  end

  def self.most_followed(n)
    QuestionFollow.most_followed_questions(n)
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

  def followers
    QuestionFollow.followers_for_question_id(id)
  end
end

class QuestionFollow < SuperTable
  TABLE_NAME = 'question_follows'

  def self.followers_for_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, question_id: question_id)
      SELECT
        u.*
      FROM
        #{TABLE_NAME} qf
      JOIN
        users u ON qf.user_id = u.id
      WHERE
        question_id = :question_id
      SQL

    data.map { |datum| User.new(datum) }
  end

  def self.followed_questions_for_user_id(user_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, user_id: user_id)
      SELECT
        q.*
      FROM
        #{TABLE_NAME} qf
      JOIN
        questions q ON qf.question_id = q.id
      WHERE
        qf.user_id = :user_id
      SQL
    data.map  { |datum| Question.new(datum) }
  end

  def self.most_followed_questions(n)
    data = QuestionsDatabase.instance.execute(<<-SQL, n: n)
      SELECT
        q.*
      FROM
        #{TABLE_NAME} qf
      JOIN
        questions q ON qf.question_id = q.id
      GROUP BY
        qf.question_id
      ORDER BY
        COUNT(qf.question_id) DESC
      LIMIT
        :n
    SQL
    data.map  { |datum| Question.new(datum) }
  end

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

    data.map do |datum|
      self.new(datum)
    end
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
    data.map { |datum| self.new(datum) }
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
    # SELECT
    #   replies.*
    # FROM
    #   replies
    # WHERE
    #   parent_id = ?
    q = Question.find_by_id(question_id)
    child_replies = []
    # q.replies.select {}
    q.replies.each do |reply|
      child_replies << reply if reply.parent_id == id
    end
    child_replies
  end
end

class QuestionLike < SuperTable
  TABLE_NAME = 'question_likes'

  def self.likers_for_question_id(question_id)
    data = QuestionsDatabase.instance.execute(<<-SQL, question_id: question_id)
      SELECT
        u.*
      FROM
        #{TABLE_NAME} ql
      JOIN
        users u ON ql.user_id = u.id
      WHERE
        ql.question_id = :question_id
      SQL
    data.map { |datum| User.new(datum) }
  end

  attr_accessor :question_id, :user_id

  def initialize(options = {})
    @id = options['id']
    @question_id = options['question_id']
    @user_id = options['user_id']
  end
end

# Where we finished until
# Hard

# These involve GROUP BY and ORDER. Use JOINs to solve these, do not use Ruby iteration methods.
#
# QuestionFollow::most_followed_questions(n)
# Fetches the n most followed questions.
# Question::most_followed(n)
# Simple call to QuestionFollow
# If you haven't already, add a QuestionLike class to use your join table question_likes. Some easy queries:
#
# QuestionLike::likers_for_question_id(question_id)
