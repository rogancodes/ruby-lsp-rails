# typed: true
# frozen_string_literal: true

require "test_helper"

module RubyLsp
  module Rails
    class HoverTest < ActiveSupport::TestCase
      test "hook returns model column information" do
        expected_response = {
          schema_file: "#{dummy_root}/db/schema.rb",
          columns: [
            ["id", "integer", nil, false],
            ["first_name", "string", "", true],
            ["last_name", "string", nil, true],
            ["age", "integer", "0", true],
            ["created_at", "datetime", nil, false],
            ["updated_at", "datetime", nil, false],
            ["country_id", "integer", nil, false],
            ["active", "boolean", "true", false],
          ],
          primary_keys: ["id"],
          foreign_keys: ["country_id"],
          indexes: [{ name: "index_users_on_country_id", columns: ["country_id"], unique: false }],
        }

        RunnerClient.any_instance.stubs(model: expected_response)

        response = hover_on_source(<<~RUBY, { line: 3, character: 0 })
          class User < ApplicationRecord
          end

          User
        RUBY

        assert_equal(<<~CONTENT.chomp, response.contents.value)
          ```ruby
          User
          ```

          **Definitions**: [fake.rb](file:///fake.rb#L1,1-2,4)


          [Schema](#{URI::Generic.from_path(path: dummy_root + "/db/schema.rb")})

          ### Columns
          - **id**: integer (PK)

          - **first_name**: string - default: ""

          - **last_name**: string

          - **age**: integer - default: 0

          - **created_at**: datetime - not null

          - **updated_at**: datetime - not null

          - **country_id**: integer (FK) - not null

          - **active**: boolean - default: true - not null

          ### Indexes
          - **index_users_on_country_id** (country_id)
        CONTENT
      end

      test "return column information for namespaced models" do
        expected_response = {
          schema_file: "#{dummy_root}/db/schema.rb",
          columns: [
            ["id", "integer", nil, false],
            ["first_name", "string", "", true],
            ["last_name", "string", nil, true],
            ["age", "integer", "0", true],
            ["created_at", "datetime", nil, false],
            ["updated_at", "datetime", nil, false],
            ["country_id", "integer", nil, false],
            ["active", "boolean", "true", false],
          ],
          primary_keys: ["id"],
          foreign_keys: [],
          indexes: [{ name: "index_users_on_country_id", columns: ["country_id"], unique: true }],
        }

        RunnerClient.any_instance.stubs(model: expected_response)

        response = hover_on_source(<<~RUBY, { line: 4, character: 6 })
          module Blog
            class User < ApplicationRecord
            end
          end

          Blog::User
        RUBY

        assert_equal(<<~CONTENT.chomp, response.contents.value)
          ```ruby
          Blog::User
          ```

          **Definitions**: [fake.rb](file:///fake.rb#L2,3-3,6)


          [Schema](#{URI::Generic.from_path(path: dummy_root + "/db/schema.rb")})

          ### Columns
          - **id**: integer (PK)

          - **first_name**: string - default: ""

          - **last_name**: string

          - **age**: integer - default: 0

          - **created_at**: datetime - not null

          - **updated_at**: datetime - not null

          - **country_id**: integer - not null

          - **active**: boolean - default: true - not null

          ### Indexes
          - **index_users_on_country_id** (country_id) (unique)
        CONTENT
      end

      test "returns column information for models with composite primary keys" do
        expected_response = {
          schema_file: "#{dummy_root}/db/schema.rb",
          columns: [
            ["order_id", "integer"],
            ["product_id", "integer"],
            ["note", "string"],
            ["created_at", "datetime"],
            ["updated_at", "datetime"],
          ],
          primary_keys: ["order_id", "product_id"],
          foreign_keys: [],
          indexes: [],
        }

        RunnerClient.any_instance.stubs(model: expected_response)

        response = hover_on_source(<<~RUBY, { line: 3, character: 0 })
          class CompositePrimaryKey < ApplicationRecord
          end

          CompositePrimaryKey
        RUBY

        assert_equal(<<~CONTENT.chomp, response.contents.value)
          ```ruby
          CompositePrimaryKey
          ```

          **Definitions**: [fake.rb](file:///fake.rb#L1,1-2,4)


          [Schema](#{URI::Generic.from_path(path: dummy_root + "/db/schema.rb")})

          ### Columns
          - **order_id**: integer (PK)

          - **product_id**: integer (PK)

          - **note**: string - not null

          - **created_at**: datetime - not null

          - **updated_at**: datetime - not null
        CONTENT
      end

      test "handles `db/structure.sql` instead of `db/schema.rb`" do
        expected_response = {
          schema_file: "#{dummy_root}/db/structure.sql",
          columns: [],
          primary_keys: [],
          foreign_keys: [],
          indexes: [],
        }

        RunnerClient.any_instance.stubs(model: expected_response)

        response = hover_on_source(<<~RUBY, { line: 3, character: 0 })
          class User < ApplicationRecord
          end

          User
        RUBY

        assert_includes(
          response.contents.value,
          "[Schema](#{URI::Generic.from_path(path: dummy_root + "/db/structure.sql")})",
        )
      end

      test "handles neither `db/structure.sql` nor `db/schema.rb` being present" do
        expected_response = {
          schema_file: nil,
          columns: [],
          primary_keys: [],
          foreign_keys: [],
          indexes: [],
        }

        RunnerClient.any_instance.stubs(model: expected_response)

        response = hover_on_source(<<~RUBY, { line: 3, character: 0 })
          class User < ApplicationRecord
          end

          User
        RUBY

        refute_match(/Schema/, response.contents.value)
      end

      private

      def hover_on_source(source, position)
        with_server(source, stub_no_typechecker: true) do |server, uri|
          server.process_message(
            id: 1,
            method: "textDocument/hover",
            params: { textDocument: { uri: uri }, position: position },
          )

          result = pop_result(server)
          result.response
        end
      end
    end
  end
end
