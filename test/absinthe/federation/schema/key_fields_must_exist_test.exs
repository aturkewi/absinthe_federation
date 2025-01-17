defmodule Absinthe.Federation.Schema.KeyFieldsMustExistTest do
  use Absinthe.Federation.Case, async: true

  @valid_schema """
    defmodule ValidSchema do
      use Absinthe.Schema
      use Absinthe.Federation.Schema

      query do
        extends()
      end

      object :product do
        extends()
        key_fields(["productUuid", "name"])

        field :product_uuid, non_null(:id), do: external()
        field :name, non_null(:string), do: external()
      end
    end
  """

  @flat_key_schema """
    defmodule FlatKeySchema do
      use Absinthe.Schema
      use Absinthe.Federation.Schema

      query do
        extends()
      end

      object :product do
        key_fields(["productUuid", "name"])
        field :id, non_null(:id)
      end
    end
  """

  @nested_key_schema """
    defmodule NestedKeySchema do
      use Absinthe.Schema
      use Absinthe.Federation.Schema

      query do
        extends()
      end

      object :product_variation do
        field :product_uuid, non_null(:id)
      end

      object :product do
        key_fields("uuid variation { productUuid }")

        field :upc, non_null(:string)
        field :sku, non_null(:string)
        field :variation, non_null(:product_variation)
      end
    end
  """

  @nested_ref_key_schema """
    defmodule NestedRefKeySchema do
      use Absinthe.Schema
      use Absinthe.Federation.Schema

      query do
        extends()
      end

      object :product_variation do
        field :uuid, non_null(:id)
        field :change, non_null(:variation_change)
      end

      object :variation_change do
        field :name, :string
      end

      object :nested_product do
        # level 1: `:uuid`
        # level 2: `:id`
        # level 3: `:change_name`
        key_fields("uuid variation { id change { change_name } }")
        field :upc, non_null(:string)
        field :sku, non_null(:string)
        field :variation, non_null(:product_variation)
      end
    end
  """

  @invalid_syntax_schema """
  defmodule InvalidSyntaxSchema do
    use Absinthe.Schema
    use Absinthe.Federation.Schema

    query do
      extends()
    end

    object :product do
      key_fields("id { (variation id) } ")
      field :id, non_null(:id)
      field :variation, non_null(:product_variation)
    end

    object :product_variation do
      field :id, non_null(:id)
    end
  end
  """

  @object_not_exist_schema1 """
  defmodule ObjectNotExistSchema1 do
    use Absinthe.Schema
    use Absinthe.Federation.Schema

    query do
      extends()
    end

    object :product do
      key_fields("id variation { id }")
      field :id, non_null(:id)
      field :product_variation, non_null(:product_variation)
    end

    object :product_variation do
      field :id, non_null(:id)
    end
  end
  """

  @object_not_exist_schema2 """
  defmodule ObjectNotExistSchema2 do
    use Absinthe.Schema
    use Absinthe.Federation.Schema

    query do
      extends()
    end

    object :product do
      key_fields("id variation { id }")
      field :id, non_null(:id)
      field :variation, non_null(:string)
    end

    object :product_variation do
      field :id, non_null(:id)
    end
  end
  """

  test "no errors for valid schema" do
    assert {_, _} = Code.eval_string(@valid_schema)
  end

  test "it should throw an error when flat key fields not exist" do
    assert %{phase_errors: [error2, error1]} = catch_error(Code.eval_string(@flat_key_schema))
    assert %{message: "The @key \"productUuid\" does not exist in :product object.\n"} = error1
    assert %{message: "The @key \"name\" does not exist in :product object.\n"} = error2
  end

  test "it should throw an error when nested key fields not exist in object" do
    error = ~r/The field \"uuid\" of @key \"uuid variation { productUuid }\" does not exist./
    assert_raise(Absinthe.Schema.Error, error, fn -> Code.eval_string(@nested_key_schema) end)
  end

  test "it should throw an error when nested key fields not exist in schema" do
    assert %{phase_errors: [error3, error2, error1]} = catch_error(Code.eval_string(@nested_ref_key_schema))

    assert %{message: "The field \"uuid\" of @key \"uuid variation { id change { change_name } }\" does not exist.\n"} =
             error1

    assert %{message: "The field \"id\" of @key \"uuid variation { id change { change_name } }\" does not exist.\n"} =
             error2

    assert %{
             message:
               "The field \"change_name\" of @key \"uuid variation { id change { change_name } }\" does not exist.\n"
           } = error3
  end

  test "it should throw an error when syntax error" do
    error = ~r/The @key \"id { \(variation id\) } \" has a syntax error./
    assert_raise(Absinthe.Schema.Error, error, fn -> Code.eval_string(@invalid_syntax_schema) end)
  end

  test "it should throw an error when object does not exist" do
    error = ~r/The object \"variation\" of @key \"id variation { id }\" does not exist./
    assert_raise(Absinthe.Schema.Error, error, fn -> Code.eval_string(@object_not_exist_schema1) end)
  end

  test "it should throw an error when object ref isn't an object" do
    error = ~r/The object \"variation\" of @key \"id variation { id }\" does not exist./
    assert_raise(Absinthe.Schema.Error, error, fn -> Code.eval_string(@object_not_exist_schema2) end)
  end
end
